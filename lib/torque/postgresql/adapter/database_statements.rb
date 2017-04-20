module Torque
  module PostgreSQL
    module Adapter
      module DatabaseStatements

        EXTENDED_DATABASE_TYPES = %i(enum interval)

        # Check if a given type is valid.
        def valid_type?(type)
          super || extended_types.include?(type)
        end

        # Get the list of extended types
        def extended_types
          EXTENDED_DATABASE_TYPES
        end

        # Returns true if type exists.
        def type_exists?(name)
          user_defined_types.key? name.to_s
        end
        alias data_type_exists? type_exists?

        # Configure the interval format
        def configure_connection
          super
          execute("SET SESSION IntervalStyle TO 'iso_8601'", 'SCHEMA')
        end

        # Change some of the types being mapped
        def initialize_type_map(m)
          super
          m.register_type 'interval', OID::Interval.new
        end

        # Add the composite types to be loaded too.
        def load_additional_types(type_map, oids = nil)
          super

          filter = "AND     a.typelem::integer IN (%s)" % oids.join(", ") if oids

          query = <<-SQL
            SELECT      a.typelem AS oid, t.typname, t.typelem,
                        t.typdelim, t.typbasetype, t.typtype
            FROM        pg_type t
            INNER JOIN  pg_type a ON (a.oid = t.typarray)
            LEFT JOIN   pg_catalog.pg_namespace n ON n.oid = t.typnamespace
            WHERE       n.nspname NOT IN ('pg_catalog', 'information_schema')
            AND     t.typtype IN ( 'e' )
            #{filter}
            AND     NOT EXISTS(
                      SELECT 1 FROM pg_catalog.pg_type el
                        WHERE el.oid = t.typelem AND el.typarray = t.oid
                      )
            AND     (t.typrelid = 0 OR (
                      SELECT c.relkind = 'c' FROM pg_catalog.pg_class c
                        WHERE c.oid = t.typrelid
                      ))
          SQL

          execute_and_clear(query, 'SCHEMA', []) do |records|
            records.each do |row|
              typtype = row['typtype']
              type = begin
                case
                when typtype == 'e'.freeze then OID::Enum.create(row)
                end
              end

              type_map.register_type row['oid'].to_i, type
            end
          end
        end

        # Gets a list of user defined types.
        # You can even choose the +typcategory+ filter
        def user_defined_types(category = nil)
          category_condition = "AND     typtype = '#{category}'" unless category.nil?
          select_all(<<-SQL).rows.to_h
            SELECT      t.typname AS name,
                        CASE t.typtype
                        WHEN 'e' THEN 'enum'
                        END AS type
            FROM        pg_type t
            LEFT JOIN   pg_catalog.pg_namespace n ON n.oid = t.typnamespace
            WHERE       n.nspname NOT IN ('pg_catalog', 'information_schema')
            #{category_condition}
            AND     NOT EXISTS(
                      SELECT 1 FROM pg_catalog.pg_type el
                        WHERE el.oid = t.typelem AND el.typarray = t.oid
                      )
            AND     (t.typrelid = 0 OR (
                      SELECT c.relkind = 'c' FROM pg_catalog.pg_class c
                        WHERE c.oid = t.typrelid
                      ))
            ORDER BY    t.typtype DESC
          SQL
        end

      end
    end
  end
end
