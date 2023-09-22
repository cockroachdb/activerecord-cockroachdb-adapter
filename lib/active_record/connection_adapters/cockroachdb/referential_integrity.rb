# frozen_string_literal: true

# The PostgresSQL Adapter's ReferentialIntegrity module can disable and
# re-enable foreign key constraints by disabling all table triggers. Since
# triggers are not available in CockroachDB, we have to remove foreign keys and
# re-add them via the ActiveRecord API.
#
# This module is commonly used to load test fixture data without having to worry
# about the order in which that data is loaded.
module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      module ReferentialIntegrity
        # CockroachDB will raise a `PG::ForeignKeyViolation` when re-enabling
        # referential integrity (e.g: adding a foreign key with invalid data
        # raises).
        # So foreign keys should always be valid for that matter.
        def all_foreign_keys_valid?
          true
        end

        def disable_referential_integrity
          foreign_keys = tables.map { |table| foreign_keys(table) }.flatten

          foreign_keys.each do |foreign_key|
            remove_foreign_key(foreign_key.from_table, name: foreign_key.options[:name])
          end

          yield

          # Prefixes and suffixes are added in add_foreign_key
          # in AR7+ so we need to temporarily disable them here,
          # otherwise prefixes/suffixes will be erroneously added.
          old_prefix = ActiveRecord::Base.table_name_prefix
          old_suffix = ActiveRecord::Base.table_name_suffix

          ActiveRecord::Base.table_name_prefix = ""
          ActiveRecord::Base.table_name_suffix = ""

          begin
            foreign_keys.each do |foreign_key|
              begin
                add_foreign_key(foreign_key.from_table, foreign_key.to_table, **foreign_key.options)
              rescue ActiveRecord::StatementInvalid => error
                if error.cause.class == PG::DuplicateObject
                  # This error is safe to ignore because the yielded caller
                  # already re-added the foreign key constraint.
                else
                  raise error
                end
              end
            end
          ensure
            ActiveRecord::Base.table_name_prefix = old_prefix
            ActiveRecord::Base.table_name_suffix = old_suffix
          end
        end
      end
    end
  end
end
