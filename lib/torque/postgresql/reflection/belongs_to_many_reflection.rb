module Torque
  module PostgreSQL
    module Reflection
      class BelongsToManyReflection < ::ActiveRecord::Reflection::AssociationReflection
        def macro
          :belongs_to_many
        end

        def connected_through_array?
          true
        end

        def collection?
          true
        end

        def association_class
          Associations::BelongsToManyAssociation
        end

        def foreign_key
          @foreign_key ||= options[:primary_key] || derive_foreign_key.freeze
        end

        def association_foreign_key
          @association_foreign_key ||= foreign_key
        end

        def active_record_primary_key
          @active_record_primary_key ||= options[:foreign_key] || derive_primary_key
        end

        private

          def derive_foreign_key
            klass.primary_key
          end

          def derive_primary_key
            "#{name.to_s.singularize}_ids"
          end
      end

      ::ActiveRecord::Reflection.const_set(:BelongsToManyReflection, BelongsToManyReflection)
      ::ActiveRecord::Reflection::AssociationReflection::VALID_AUTOMATIC_INVERSE_MACROS
        .push(:belongs_to_many)
    end
  end
end
