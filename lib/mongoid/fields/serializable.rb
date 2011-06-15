# encoding: utf-8
module Mongoid #:nodoc:
  module Fields #:nodoc:

    # Defines the behaviour for defined fields in the document.
    #
    # For people who want to have custom field types in their
    # applications and want control over the serialization process
    # to and from the domain model and MongoDB you will need to include
    # this module in your custom type class. You will also need to define
    # either a #serialize and #deserialize instance method, where previously
    # these were a .set and .get class method respectively.
    #
    #   class MyCustomType
    #     include Mongoid::Fields::Serializable
    #
    #     def deserialize(object)
    #       # Do something to convert it from Mongo to my type.
    #     end
    #
    #     def serialize(object)
    #       # Do something to convert from my type to MongoDB friendly.
    #     end
    #   end
    module Serializable

      # Set readers for the instance variables.
      attr_reader :default_value, :label, :name, :options

      # When reading the field do we need to cast the value? This holds true when
      # times are stored or for big decimals which are stored as strings.
      #
      # @example Typecast on a read?
      #   field.cast_on_read?
      #
      # @return [ true, false ] If the field should be cast.
      #
      # @since 2.1.0
      def cast_on_read?
        @cast_on_read ||=
          self.class.public_instance_methods(false).include?(:deserialize)
      end

      # Get the default value for the field.
      #
      # @example Get the default.
      #   field.default
      #
      # @return [ Object ] The default value.
      #
      # @since 2.1.0
      def default
        if default_value.respond_to?(:call)
          serialize(default_value.call)
        else
          serialize(default_value)
        end
      end

      # Deserialize this field from the type stored in MongoDB to the type
      # defined on the model
      #
      # @example Deserialize the field.
      #   field.deserialize(object)
      #
      # @param [ Object ] object The object to cast.
      #
      # @return [ Object ] The converted object.
      #
      # @since 2.1.0
      def deserialize(object); object; end

      # Create the new field with a name and optional additional options.
      #
      # @example Create the new field.
      #   Field.new(:name, :type => String)
      #
      # @param [ Hash ] options The field options.
      #
      # @option options [ Class ] :type The class of the field.
      # @option options [ Object ] :default The default value for the field.
      # @option options [ String ] :label The field's label.
      #
      # @since 2.1.0
      def initialize(name, options = {})
        @name, @options = name, options
        @default_value, @label = options[:default], options[:label]
      end

      # Serialize the object from the type defined in the model to a MongoDB
      # compatible object to store.
      #
      # @example Serialize the field.
      #   field.serialize(object)
      #
      # @param [ Object ] object The object to cast.
      #
      # @return [ Object ] The converted object.
      #
      # @since 2.1.0
      def serialize(object); object; end

      # Get the type of this field - inferred from the class name.
      #
      # @example Get the type.
      #   field.type
      #
      # @return [ Class ] The name of the class.
      #
      # @since 2.1.0
      def type
        @type ||= options[:type] || Object
      end

      class << self

        # Return a map of custom option names to their handlers.
        #
        # @example
        #   Mongoid::Field.options
        #   # => { :required => #<Proc:0x00000100976b38> }
        #
        # @return [ Hash ] the option map
        #
        # @since 2.1.0
        def options
          @options ||= {}
        end

        # Stores the provided block to be run when the option name specified is
        # defined on a field.
        #
        # No assumptions are made about what sort of work the handler might
        # perform, so it will always be called if the `option_name` key is
        # provided in the field definition -- even if it is false or nil.
        #
        # @example
        #   Mongoid::Field.option :required do |model, field, value|
        #     model.validates_presence_of field if value
        #   end
        #
        # @param [ Symbol ] option_name the option name to match against
        # @param [ Proc ] block the handler to execute when the option is
        #   provided.
        #
        # @since 2.1.0
        def option(option_name, &block)
          options[option_name] = block
        end
      end
    end
  end
end
