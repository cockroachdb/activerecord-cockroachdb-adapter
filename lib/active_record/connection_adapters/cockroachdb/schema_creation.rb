# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      class SchemaCreation < PostgreSQL::SchemaCreation # :nodoc:
        private
          def add_column_options!(sql, options)
            if options[:hidden]
              sql << " NOT VISIBLE"
            end
            super
          end
      end
    end
  end
end

