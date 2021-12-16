require "active_record/migration"
require "active_record/migration/compatibility"

module ActiveRecord
  class Migration
    module CockroachDB
      module Compatibility
        module V7_0Patch
          # Override. Use "CockroachDB" instead of "PostgreSQL"
          def compatible_timestamp_type(type, connection)
            if connection.adapter_name == "CockroachDB"
              # For Rails <= 6.1, :datetime was aliased to :timestamp
              # See: https://github.com/rails/rails/blob/v6.1.3.2/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb#L108
              # From Rails 7 onwards, you can define what :datetime resolves to (the default is still :timestamp)
              # See `ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.datetime_type`
              type.to_sym == :datetime ? :timestamp : type
            else
              type
            end
          end
        end
      end
    end
  end
end

prepend_mod = ActiveRecord::Migration::CockroachDB::Compatibility::V7_0Patch
ActiveRecord::Migration::Compatibility::V6_1::PostgreSQLCompat.singleton_class.prepend(prepend_mod)
