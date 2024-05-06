# frozen_string_literal: true

require 'mongoid/contextual/aggregable/memory'
require 'mongoid/association/eager_loadable'

module Mongoid
  module Contextual

    # Context object used for performing bulk query and persistence
    # operations on documents which have been loaded into application
    # memory. The method interface of this class is consistent with
    # Mongoid::Contextual::Mongo.
    class Memory
      include Enumerable
      include Aggregable::Memory
      include Association::EagerLoadable
      include Queryable
      include Positional

      # @attribute [r] root The root document.
      # @attribute [r] path The atomic path.
      # @attribute [r] selector The root document selector.
      # @attribute [r] matching The in memory documents that match the selector.
      attr_reader :documents, :path, :root, :selector

      # Check if the context is equal to the other object.
      #
      # @example Check equality.
      #   context == []
      #
      # @param [ Array ] other The other array.
      #
      # @return [ true | false ] If the objects are equal.
      def ==(other)
        return false unless other.respond_to?(:entries)

        entries == other.entries
      end

      # Delete all documents in the database that match the selector.
      #
      # @example Delete all the documents.
      #   context.delete
      #
      # @return [ nil ] Nil.
      def delete
        deleted = count
        removed = map do |doc|
          prepare_remove(doc)
          doc.send(:as_attributes)
        end
        unless removed.empty?
          collection.find(selector).update_one(
            positionally(selector, '$pullAll' => { path => removed }),
            session: _session
          )
        end
        deleted
      end
      alias_method :delete_all, :delete

      # Destroy all documents in the database that match the selector.
      #
      # @example Destroy all the documents.
      #   context.destroy
      #
      # @return [ nil ] Nil.
      def destroy
        deleted = count
        each do |doc|
          documents.delete_one(doc)
          doc.destroy
        end
        deleted
      end
      alias_method :destroy_all, :destroy

      # Get the distinct values in the db for the provided field.
      #
      # @example Get the distinct values.
      #   context.distinct(:name)
      #
      # @param [ String | Symbol ] field The name of the field.
      #
      # @return [ Array<Object> ] The distinct values for the field.
      def distinct(field)
        pluck(field).uniq
      end

      # Iterate over the context. If provided a block, yield to a Mongoid
      # document for each, otherwise return an enum.
      #
      # @example Iterate over the context.
      #   context.each do |doc|
      #     puts doc.name
      #   end
      #
      # @return [ Enumerator ] The enumerator.
      def each(&block)
        if block
          documents_for_iteration.each(&block)
          self
        else
          to_enum
        end
      end

      # Do any documents exist for the context.
      #
      # @example Do any documents exist for the context.
      #   context.exists?
      #
      # @example Do any documents exist for given _id.
      #   context.exists?(BSON::ObjectId(...))
      #
      # @example Do any documents exist for given conditions.
      #   context.exists?(name: "...")
      #
      # @param [ Hash | Object | false ] id_or_conditions an _id to
      #   search for, a hash of conditions, nil or false.
      #
      # @return [ true | false ] If the count is more than zero.
      #   Always false if passed nil or false.
      def exists?(id_or_conditions = :none)
        case id_or_conditions
        when :none then any?
        when nil, false then false
        when Hash then Memory.new(criteria.where(id_or_conditions)).exists?
        else Memory.new(criteria.where(_id: id_or_conditions)).exists?
        end
      end

      # Get the first document in the database for the criteria's selector.
      #
      # @example Get the first document.
      #   context.first
      #
      # @param [ Integer ] limit The number of documents to return.
      #
      # @return [ Mongoid::Document ] The first document.
      def first(limit = nil)
        if limit
          eager_load(documents.first(limit))
        else
          eager_load([documents.first]).first
        end
      end
      alias_method :one, :first
      alias_method :find_first, :first

      # Get the first document in the database for the criteria's selector or
      # raise an error if none is found.
      #
      # @example Get the first document.
      #   context.first!
      #
      # @return [ Mongoid::Document ] The first document.
      #
      # @raise [ Mongoid::Errors::DocumentNotFound ] raises when there are no
      #   documents to take.
      def first!
        first || raise_document_not_found_error
      end

      # Create the new in memory context.
      #
      # @example Create the new context.
      #   Memory.new(criteria)
      #
      # @param [ Mongoid::Criteria ] criteria The criteria.
      def initialize(criteria)
        @criteria = criteria
        @klass = criteria.klass
        @documents = criteria.documents.select do |doc|
          @root ||= doc._root
          @collection ||= root.collection
          doc._matches?(criteria.selector)
        end
        apply_sorting
        apply_options
      end

      # Increment a value on all documents.
      #
      # @example Perform the increment.
      #   context.inc(likes: 10)
      #
      # @param [ Hash ] incs The operations.
      #
      # @return [ Enumerator ] The enumerator.
      def inc(incs)
        each do |document|
          document.inc(incs)
        end
      end

      # Get the last document in the database for the criteria's selector.
      #
      # @example Get the last document.
      #   context.last
      #
      # @param [ Integer ] limit The number of documents to return.
      #
      # @return [ Mongoid::Document ] The last document.
      def last(limit = nil)
        if limit
          eager_load(documents.last(limit))
        else
          eager_load([documents.last]).first
        end
      end

      # Get the last document in the database for the criteria's selector or
      # raise an error if none is found.
      #
      # @example Get the last document.
      #   context.last!
      #
      # @return [ Mongoid::Document ] The last document.
      #
      # @raise [ Mongoid::Errors::DocumentNotFound ] raises when there are no
      #   documents to take.
      def last!
        last || raise_document_not_found_error
      end

      # Get the length of matching documents in the context.
      #
      # @example Get the length of matching documents.
      #   context.length
      #
      # @return [ Integer ] The matching length.
      def length
        documents.length
      end
      alias_method :size, :length

      # Limits the number of documents that are returned.
      #
      # @example Limit the documents.
      #   context.limit(20)
      #
      # @param [ Integer ] value The number of documents to return.
      #
      # @return [ Memory ] The context.
      def limit(value)
        self.limiting = value
        self
      end

      # Pluck the field values in memory.
      #
      # @example Get the values in memory.
      #   context.pluck(:name)
      #
      # @param [ [ String | Symbol ]... ] *fields Field(s) to pluck.
      #
      # @return [ Array<Object> | Array<Array<Object>> ] The plucked values.
      def pluck(*fields)
        documents.map do |doc|
          pluck_from_doc(doc, *fields)
        end
      end

      # Iterate through plucked field values in memory.
      #
      # @example Iterate through the values for null context.
      #   context.pluck_each(:name) { |name| puts name }
      #
      # @param [ [ String | Symbol ]... ] *fields Field(s) to pluck.
      # @param [ Proc ] &block The block to call once for each plucked
      #   result.
      #
      # @return [ Enumerator | Memory ] An enumerator, or the context
      #   if a block was given.
      def pluck_each(*fields, &block)
        enum = pluck(*fields).each(&block)
        block ? self : enum
      end

      # Pick the field values in memory.
      #
      # @example Get the values in memory.
      #   context.pick(:name)
      #
      # @param [ [ String | Symbol ]... ] *fields Field(s) to pick.
      #
      # @return [ Object | Array<Object> ] The picked values.
      def pick(*fields)
        return unless (doc = documents.first)

        pluck_from_doc(doc, *fields)
      end

      # Tally the field values in memory.
      #
      # @example Get the counts of values in memory.
      #   context.tally(:name)
      #
      # @param [ String | Symbol ] field Field to tally.
      # @param [ Boolean ] :unwind Whether to tally array
      #   member values individually. Default false.
      #
      # @return [ Hash ] The hash of counts.
      def tally(field, unwind: false)
        documents.each_with_object({}) do |doc, tallies|
          key = retrieve_value_at_path(doc, field)

          if unwind && key.is_a?(Array)
            key.each do |array_value|
              tallies[array_value] ||= 0
              tallies[array_value] += 1
            end
          else
            tallies[key] ||= 0
            tallies[key] += 1
          end
        end
      end

      # Take the given number of documents from the database.
      #
      # @example Take a document.
      #   context.take
      #
      # @param [ Integer | nil ] limit The number of documents to take or nil.
      #
      # @return [ Mongoid::Document ] The document.
      def take(limit = nil)
        if limit
          eager_load(documents.take(limit))
        else
          eager_load([documents.first]).first
        end
      end

      # Take the given number of documents from the database or raise an error
      # if none are found.
      #
      # @example Take a document.
      #   context.take
      #
      # @return [ Mongoid::Document ] The document.
      #
      # @raise [ Mongoid::Errors::DocumentNotFound ] raises when there are no
      #   documents to take.
      def take!
        take || raise_document_not_found_error
      end

      # Skips the provided number of documents.
      #
      # @example Skip the documents.
      #   context.skip(20)
      #
      # @param [ Integer ] value The number of documents to skip.
      #
      # @return [ Memory ] The context.
      def skip(value)
        self.skipping = value
        self
      end

      # Sorts the documents by the provided spec.
      #
      # @example Sort the documents.
      #   context.sort(name: -1, title: 1)
      #
      # @param [ Hash ] values The sorting values as field/direction(1/-1)
      #   pairs.
      #
      # @return [ Memory ] The context.
      def sort(values)
        in_place_sort(values) and self
      end

      # Update the first matching document atomically.
      #
      # @example Update the matching document.
      #   context.update(name: "Smiths")
      #
      # @param [ Hash ] attributes The new attributes for the document.
      #
      # @return [ nil | false ] False if no attributes were provided.
      def update(attributes = nil)
        update_documents(attributes, [first])
      end

      # Update all the matching documents atomically.
      #
      # @example Update all the matching documents.
      #   context.update_all(name: "Smiths")
      #
      # @param [ Hash ] attributes The new attributes for each document.
      #
      # @return [ nil | false ] False if no attributes were provided.
      def update_all(attributes = nil)
        update_documents(attributes, entries)
      end

      # Get the second document in the database for the criteria's selector.
      #
      # @example Get the second document.
      #   context.second
      #
      # @return [ Mongoid::Document ] The second document.
      def second
        eager_load([documents.second]).first
      end

      # Get the second document in the database for the criteria's selector or
      # raise an error if none is found.
      #
      # @example Get the second document.
      #   context.second!
      #
      # @raise [ Mongoid::Errors::DocumentNotFound ] raises when there are no
      #   documents to take.
      def second!
        second || raise_document_not_found_error
      end

      # Get the third document in the database for the criteria's selector.
      #
      # @example Get the third document.
      #   context.third
      #
      # @return [ Mongoid::Document ] The third document.
      def third
        eager_load([documents.third]).first
      end

      # Get the third document in the database for the criteria's selector or
      # raise an error if none is found.
      #
      # @example Get the third document.
      #   context.third!
      #
      # @raise [ Mongoid::Errors::DocumentNotFound ] raises when there are no
      #   documents to take.
      def third!
        third || raise_document_not_found_error
      end

      # Get the fourth document in the database for the criteria's selector.
      #
      # @example Get the fourth document.
      #   context.fourth
      #
      # @return [ Mongoid::Document ] The fourth document.
      def fourth
        eager_load([documents.fourth]).first
      end

      # Get the fourth document in the database for the criteria's selector or
      # raise an error if none is found.
      #
      # @example Get the fourth document.
      #   context.fourth!
      #
      # @raise [ Mongoid::Errors::DocumentNotFound ] raises when there are no
      #   documents to take.
      def fourth!
        fourth || raise_document_not_found_error
      end

      # Get the fifth document in the database for the criteria's selector.
      #
      # @example Get the fifth document.
      #   context.fifth
      #
      # @return [ Mongoid::Document ] The fifth document.
      def fifth
        eager_load([documents.fifth]).first
      end

      # Get the fifth document in the database for the criteria's selector or
      # raise an error if none is found.
      #
      # @example Get the fifth document.
      #   context.fifth!
      #
      # @return [ Mongoid::Document ] The fifth document.
      #
      # @raise [ Mongoid::Errors::DocumentNotFound ] raises when there are no
      #   documents to take.
      def fifth!
        fifth || raise_document_not_found_error
      end

      # Get the second to last document in the database for the criteria's selector.
      #
      # @example Get the second to last document.
      #   context.second_to_last
      #
      # @return [ Mongoid::Document ] The second to last document.
      def second_to_last
        eager_load([documents.second_to_last]).first
      end

      # Get the second to last document in the database for the criteria's selector or
      # raise an error if none is found.
      #
      # @example Get the second to last document.
      #   context.second_to_last!
      #
      # @return [ Mongoid::Document ] The second to last document.
      #
      # @raise [ Mongoid::Errors::DocumentNotFound ] raises when there are no
      #   documents to take.
      def second_to_last!
        second_to_last || raise_document_not_found_error
      end

      # Get the third to last document in the database for the criteria's selector.
      #
      # @example Get the third to last document.
      #   context.third_to_last
      #
      # @return [ Mongoid::Document ] The third to last document.
      def third_to_last
        eager_load([documents.third_to_last]).first
      end

      # Get the third to last document in the database for the criteria's selector or
      # raise an error if none is found.
      #
      # @example Get the third to last document.
      #   context.third_to_last!
      #
      # @return [ Mongoid::Document ] The third to last document.
      #
      # @raise [ Mongoid::Errors::DocumentNotFound ] raises when there are no
      #   documents to take.
      def third_to_last!
        third_to_last || raise_document_not_found_error
      end

      private

      # Get the documents the context should iterate. This follows 3 rules:
      #
      # @api private
      #
      # @example Get the documents for iteration.
      #   context.documents_for_iteration
      #
      # @return [ Array<Mongoid::Document> ] The docs to iterate.
      def documents_for_iteration
        docs = documents[skipping || 0, limiting || documents.length] || []
        eager_load(docs) if eager_loadable?
        docs
      end

      # Update the provided documents with the attributes.
      #
      # @api private
      #
      # @example Update the documents.
      #   context.update_documents({}, doc)
      #
      # @param [ Hash ] attributes The attributes.
      # @param [ Array<Mongoid::Document> ] docs The docs to update.
      def update_documents(attributes, docs)
        return false if !attributes || docs.empty?

        updates = { '$set' => {} }
        docs.each do |doc|
          @selector ||= root.atomic_selector
          doc.write_attributes(attributes)
          updates['$set'].merge!(doc.atomic_updates['$set'] || {})
          doc.move_changes
        end
        collection.find(selector).update_one(updates, session: _session) unless updates['$set'].empty?
      end

      # Get the limiting value.
      #
      # @api private
      #
      # @example Get the limiting value.
      #
      # @return [ Integer ] The limit.
      def limiting
        defined?(@limiting) ? @limiting : nil
      end

      # Set the limiting value.
      #
      # @api private
      #
      # @example Set the limiting value.
      #
      # @param [ Integer ] value The limit.
      #
      # @return [ Integer ] The limit.
      attr_writer :limiting

      # Get the skipping value.
      #
      # @api private
      #
      # @example Get the skipping value.
      #
      # @return [ Integer ] The skip.
      def skipping
        defined?(@skipping) ? @skipping : nil
      end

      # Set the skipping value.
      #
      # @api private
      #
      # @example Set the skipping value.
      #
      # @param [ Integer ] value The skip.
      #
      # @return [ Integer ] The skip.
      attr_writer :skipping

      # Apply criteria options.
      #
      # @api private
      #
      # @example Apply criteria options.
      #   context.apply_options
      #
      # @return [ Memory ] self.
      def apply_options
        raise Errors::InMemoryCollationNotSupported if criteria.options[:collation]

        skip(criteria.options[:skip]).limit(criteria.options[:limit])
      end

      # Map the sort symbols to the correct MongoDB values.
      #
      # @example Apply the sorting params.
      #   context.apply_sorting
      def apply_sorting
        return unless (spec = criteria.options[:sort])

        in_place_sort(spec)
      end

      # Compare two values, handling the cases when
      # either value is nil.
      #
      # @api private
      #
      # @example Compare the two objects.
      #   context.compare(a, b)
      #
      # @param [ Object ] value_a The first object.
      # @param [ Object ] value_b The second object.
      #
      # @return [ Integer ] The comparison value.
      def compare(value_a, value_b)
        return 0 if value_a.nil? && value_b.nil?
        return 1 if value_a.nil?
        return -1 if value_b.nil?

        compare_operand(value_a) <=> compare_operand(value_b)
      end

      # Sort the documents in place.
      #
      # @example Sort the documents.
      #   context.in_place_sort(name: 1)
      #
      # @param [ Hash ] values The field/direction sorting pairs.
      def in_place_sort(values)
        documents.sort! do |a, b|
          values.map do |field, direction|
            direction * compare(a[field], b[field])
          end.detect { |value| !value.zero? } || 0
        end
      end

      # Prepare the document for batch removal.
      #
      # @api private
      #
      # @example Prepare for removal.
      #   context.prepare_remove(doc)
      #
      # @param [ Mongoid::Document ] doc The document.
      def prepare_remove(doc)
        @selector ||= root.atomic_selector
        @path ||= doc.atomic_path
        documents.delete_one(doc)
        doc._parent.remove_child(doc)
        doc.destroyed = true
      end

      def _session
        @criteria.send(:_session)
      end

      # Get the operand value to be used in comparison.
      # Adds capability to sort boolean values.
      #
      # @example Get the comparison operand.
      #   compare_operand(true) #=> 1
      #
      # @param [ Object ] value The value to be used in comparison.
      #
      # @return [ Integer | Object ] The comparison operand.
      def compare_operand(value)
        case value
        when TrueClass then 1
        when FalseClass then 0
        else value
        end
      end

      # Retrieve the value for the current document at the given field path.
      #
      # For example, if I have the following models:
      #
      #   User has_many Accounts
      #   address is a hash on Account
      #
      #   u = User.new(accounts: [ Account.new(address: { street: "W 50th" }) ])
      #   retrieve_value_at_path(u, "user.accounts.address.street")
      #   # => [ "W 50th" ]
      #
      # Note that the result is in an array since accounts is an array. If it
      # was nested in two arrays the result would be in a 2D array.
      #
      # @param [ Object ] document The object to traverse the field path.
      # @param [ String ] field_path The dotted string that represents the path
      #   to the value.
      #
      # @return [ Object | nil ] The value at the given field path or nil if it
      #   doesn't exist.
      def retrieve_value_at_path(document, field_path)
        return if field_path.blank? || !document

        segment, remaining = field_path.to_s.split('.', 2)

        curr = if document.is_a?(Document)
                 # Retrieves field for segment to check localization. Only does one
                 # iteration since there's no dots
                 res = if remaining
                         field = document.class.traverse_association_tree(segment)
                         # If this is a localized field, and there are remaining, get the
                         # _translations hash so that we can get the specified translation in
                         # the remaining
                         document.send(:"#{segment}_translations") if field&.localized?
                       end
                 meth = klass.aliased_associations[segment] || segment
                 res.nil? ? document.try(meth) : res
               elsif document.is_a?(Hash)
                 # TODO: Remove the indifferent access when implementing MONGOID-5410.
                 if document.key?(segment.to_s)
                   document[segment.to_s]
                 else
                   document[segment.to_sym]
                 end
               end

        return curr unless remaining

        if curr.is_a?(Array)
          # compact is used for consistency with server behavior.
          curr.filter_map { |d| retrieve_value_at_path(d, remaining) }
        else
          retrieve_value_at_path(curr, remaining)
        end
      end

      # Pluck the field values from the given document.
      #
      # @param [ Mongoid::Document ] doc The document to pluck from.
      # @param [ [ String | Symbol ]... ] *fields Field(s) to pluck.
      #
      # @return [ Object | Array<Object> ] The plucked values.
      def pluck_from_doc(doc, *fields)
        if fields.length == 1
          retrieve_value_at_path(doc, fields.first)
        else
          fields.map do |field|
            retrieve_value_at_path(doc, field)
          end
        end
      end

      def raise_document_not_found_error
        raise Errors::DocumentNotFound.new(klass, nil, nil)
      end
    end
  end
end
