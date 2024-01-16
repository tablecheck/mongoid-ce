# frozen_string_literal: true

module Mongoid
  class Criteria
    module Queryable
      module Extensions

        # Adds query type-casting behavior to String class.
        module String

          # Evolve the string into a mongodb friendly date.
          #
          # @example Evolve the string.
          #   "2012-1-1".__evolve_date__
          #
          # @return [ Time ] The time at UTC midnight.
          def __evolve_date__
            time = ::Time.parse(self)
            ::Time.utc(time.year, time.month, time.day, 0, 0, 0, 0)
          end

          # Evolve the string into a mongodb friendly time.
          #
          # @example Evolve the string.
          #   "2012-1-1".__evolve_time__
          #
          # @return [ Time ] The string as a time.
          def __evolve_time__
            __mongoize_time__.utc
          end

          # Get the string as a mongo expression, adding $ to the front.
          #
          # @example Get the string as an expression.
          #   "test".__mongo_expression__
          #
          # @return [ String ] The string with $ at the front.
          def __mongo_expression__
            start_with?('$') ? self : "$#{self}"
          end

          # Get the string as a sort option.
          #
          # @example Get the string as a sort option.
          #   "field ASC".__sort_option__
          #
          # @return [ Hash ] The string as a sort option hash.
          def __sort_option__
            split(/,/).inject({}) do |hash, spec|
              hash.tap do |h|
                field, direction = spec.strip.split(/\s/)
                h[field.to_sym] = Mongoid::Criteria::Translator.to_direction(direction)
              end
            end
          end

          # Get the string as a specification.
          #
          # @example Get the string as a criteria.
          #   "field".__expr_part__(value)
          #
          # @param [ Object ] value The value of the criteria.
          # @param [ true | false ] negating If the selection should be negated.
          #
          # @return [ Hash ] The selection.
          def __expr_part__(value, negating = false)
            ::String.__expr_part__(self, value, negating)
          end

          module ClassMethods

            # Get the value as a expression.
            #
            # @example Get the value as an expression.
            #   String.__expr_part__("field", value)
            #
            # @param [ String | Symbol ] key The field key.
            # @param [ Object ] value The value of the criteria.
            # @param [ true | false ] negating If the selection should be negated.
            #
            # @return [ Hash ] The selection.
            def __expr_part__(key, value, negating = false)
              if negating
                { key => { "$#{__regexp?(value) ? 'not' : 'ne'}" => value } }
              else
                { key => value }
              end
            end

            # Evolves the string into a MongoDB friendly value - in this case
            # a string.
            #
            # @example Evolve the string
            #   String.evolve(1)
            #
            # @param [ Object ] object The object to convert.
            #
            # @return [ String ] The value as a string.
            def evolve(object)
              __evolve__(object) do |obj|
                __regexp?(obj) ? obj : obj.to_s
              end
            end

            private

            # Returns whether the object is Regexp-like.
            #
            # @param [ Object ] object The object to evaluate.
            #
            # @return [ Boolean ] Whether the object is Regexp-like.
            def __regexp?(object)
              object.is_a?(Regexp) || object.is_a?(BSON::Regexp::Raw)
            end
          end
        end
      end
    end
  end
end

String.include Mongoid::Criteria::Queryable::Extensions::String
String.extend Mongoid::Criteria::Queryable::Extensions::String::ClassMethods
