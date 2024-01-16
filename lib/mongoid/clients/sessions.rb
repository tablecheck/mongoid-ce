# frozen_string_literal: true

module Mongoid
  module Clients

    # Encapsulates behavior for using sessions and transactions.
    module Sessions

      # Add class method mixin functionality.
      #
      # @todo Replace with ActiveSupport::Concern
      def self.included(base)
        base.include(ClassMethods)
      end

      module ClassMethods

        # Actions that can be used to trigger transactional callbacks.
        # @api private
        CALLBACK_ACTIONS = [:create, :destroy, :update]

        # Execute a block within the context of a session.
        #
        # @example Execute some operations in the context of a session.
        #   Band.with_session(causal_consistency: true) do
        #     band = Band.create
        #     band.records << Record.new
        #     band.save
        #     band.reload.records
        #   end
        #
        # @param [ Hash ] options The session options. Please see the driver
        #   documentation for the available session options.
        #
        # @raise [ Errors::InvalidSessionUse ] If an operation is attempted on a model using another
        #   client from which the session was started or if sessions are nested.
        #
        # @return [ Object ] The result of calling the block.
        #
        # @yieldparam [ Mongo::Session ] The session being used for the block.
        def with_session(options = {})
          if Threaded.get_session(client: persistence_context.client)
            raise Mongoid::Errors::InvalidSessionNesting.new
          end

          session = persistence_context.client.start_session(options)
          Threaded.set_session(session, client: persistence_context.client)
          yield(session)
        rescue Mongo::Error::InvalidSession => e
          if e.is_a?(Mongo::Error::SessionsNotSupported)
            raise Mongoid::Errors::SessionsNotSupported.new
          end

          raise e
        rescue Mongo::Error::OperationFailure => e
          if (e.code == 40415 && e.server_message =~ /startTransaction/) ||
             (e.code == 20 && e.server_message =~ /Transaction/)
            raise Mongoid::Errors::TransactionsNotSupported
          end

          raise e
        ensure
          Threaded.clear_session(client: persistence_context.client)
        end

        # Executes a block within the context of a transaction.
        #
        # If the block does not raise an error, the transaction is committed.
        # If an error is raised, the transaction is aborted. The error is passed on
        # except for the `Mongoid::Errors::Rollback`. This error is not passed on,
        # so you can raise is if you want to deliberately rollback the transaction.
        #
        # @param [ Hash ] options The transaction options. Please see the driver
        #   documentation for the available session options.
        # @param [ Hash ] session_options The session options. A MongoDB
        #   transaction must be started inside a session, therefore a session will
        #   be started. Please see the driver documentation for the available session options.
        #
        # @raise [ Mongoid::Errors::InvalidTransactionNesting ] If the transaction is
        #   opened on a client that already has an open transaction.
        # @raise [ Mongoid::Errors::TransactionsNotSupported ] If MongoDB deployment
        #   the client is connected to does not support transactions.
        # @raise [ Mongoid::Errors::TransactionError ] If there is an error raised
        #   by MongoDB deployment or MongoDB driver.
        #
        # @yield Provided block will be executed inside a transaction.
        def transaction(options = {}, session_options: {})
          with_session(session_options) do |session|
            session.start_transaction(options)
            yield
            commit_transaction(session)
          rescue Mongoid::Errors::Rollback
            abort_transaction(session)
          rescue Mongoid::Errors::InvalidSessionNesting
            # Session should be ended here.
            raise Mongoid::Errors::InvalidTransactionNesting
          rescue Mongo::Error::InvalidSession, Mongo::Error::InvalidTransactionOperation => e
            abort_transaction(session)
            raise Mongoid::Errors::TransactionError(e)
          rescue StandardError => e
            abort_transaction(session)
            raise e
          end
        end

        # Sets up a callback is called after a commit of a transaction.
        # The callback is called only if the document is created, updated, or destroyed
        # in the transaction.
        #
        # See +ActiveSupport::Callbacks::ClassMethods::set_callback+ for more
        # information about method parameters and possible options.
        def after_commit(*args, &block)
          set_options_for_callbacks!(args)
          set_callback(:commit, :after, *args, &block)
        end

        # Shortcut for +after_commit :hook, on: [ :create, :update ]+
        def after_save_commit(*args, &block)
          set_options_for_callbacks!(args, on: [ :create, :update ])
          set_callback(:commit, :after, *args, &block)
        end

        # Shortcut for +after_commit :hook, on: :create+.
        def after_create_commit(*args, &block)
          set_options_for_callbacks!(args, on: :create)
          set_callback(:commit, :after, *args, &block)
        end

        # Shortcut for +after_commit :hook, on: :update+.
        def after_update_commit(*args, &block)
          set_options_for_callbacks!(args, on: :update)
          set_callback(:commit, :after, *args, &block)
        end

        # Shortcut for +after_commit :hook, on: :destroy+.
        def after_destroy_commit(*args, &block)
          set_options_for_callbacks!(args, on: :destroy)
          set_callback(:commit, :after, *args, &block)
        end

        # This callback is called after a create, update, or destroy are rolled back.
        #
        # Please check the documentation of +after_commit+ for options.
        def after_rollback(*args, &block)
          set_options_for_callbacks!(args)
          set_callback(:rollback, :after, *args, &block)
        end

        private

        # @return [ Mongo::Session ] Session for the current client.
        def _session
          Threaded.get_session(client: persistence_context.client)
        end

        # This method should be used to detect whether a persistence operation
        # is executed inside transaction or not.
        #
        # Currently this method is used to detect when +after_commit+ callbacks
        # should be triggered. If we introduce implicit transactions and
        # therefore do not need to handle two different ways of triggering callbacks,
        # we may want to remove this method.
        #
        # @return [ true | false ] Whether there is a session for the current
        #   client, and there is a transaction in progress for this session.
        def in_transaction?
          _session&.in_transaction? || false
        end

        # Commits the active transaction on the session, and calls
        # after_commit callbacks on modified documents.
        #
        # @param [ Mongo::Session ] session Session on which
        #   a transaction is started.
        def commit_transaction(session)
          session.commit_transaction
          Threaded.clear_modified_documents(session).each do |doc|
            doc.run_after_callbacks(:commit)
          end
        end

        # Aborts the active transaction on the session, and calls
        # after_rollback callbacks on modified documents.
        #
        # @param [ Mongo::Session ] session Session on which
        #   a transaction is started.
        def abort_transaction(session)
          session.abort_transaction
          Threaded.clear_modified_documents(session).each do |doc|
            doc.run_after_callbacks(:rollback)
          end
        end

        # Transforms custom options for after_commit and after_rollback callbacks
        # into options for +set_callback+.
        def set_options_for_callbacks!(args)
          options = args.extract_options!
          args << options

          if options[:on]
            fire_on = Array(options[:on])
            assert_valid_transaction_action(fire_on)
            options[:if] = [
              -> { transaction_include_any_action?(fire_on) },
              *options[:if]
            ]
          end
        end

        # Asserts that the given actions are valid for after_commit
        # and after_rollback callbacks.
        #
        # @param [ Array<Symbol> ] actions Actions to be checked.
        # @raise [ ArgumentError ] If any of the actions is not valid.
        def assert_valid_transaction_action(actions)
          if (actions - CALLBACK_ACTIONS).any?
            raise ArgumentError, ":on conditions for after_commit and after_rollback callbacks have to be one of #{CALLBACK_ACTIONS}"
          end
        end

        def transaction_include_any_action?(actions)
          actions.any? do |action|
            case action
            when :create
              persisted? && previously_new_record?
            when :update
              !(previously_new_record? || destroyed?)
            when :destroy
              destroyed?
            end
          end
        end
      end
    end
  end
end
