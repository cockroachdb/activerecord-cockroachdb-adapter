# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      class SchemaDumper < ConnectionAdapters::PostgreSQL::SchemaDumper # :nodoc:
        private
          def prepare_column_options(column)
            spec = super
            if column.hidden?
              spec[:hidden] = true
            end
            spec
          end
      end
    end
  end
end

