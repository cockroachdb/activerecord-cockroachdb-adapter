module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      module Quoting
        private

        # CockroachDB does not allow inserting integer values into string
        # columns, but ActiveRecord expects this to work. CockroachDB will
        # however allow inserting string values into integer columns. It will
        # try to parse string values and convert them to integers so they can be
        # inserted in integer columns.
        #
        # We take advantage of this behavior here by forcing numeric values to
        # always be strings. Then, we won't have to make any additional changes
        # to ActiveRecord to support inserting integer values into string
        # columns.
        def _quote(value)
          case value
          when Numeric
            "'#{quote_string(value.to_s)}'"
          else
            super
          end
        end
      end
    end
  end
end
