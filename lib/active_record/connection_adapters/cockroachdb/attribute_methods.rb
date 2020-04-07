module ActiveRecord
  module CockroachDB
    module AttributeMethodsMonkeyPatch

      private

      # Filter out rowid so it doesn't get inserted by ActiveRecord. rowid is a
      # column added by CockroachDB for tables that don't define primary keys.
      # CockroachDB will automatically insert rowid values. See
      # https://www.cockroachlabs.com/docs/v19.2/create-table.html#create-a-table.
      def attributes_for_create(attribute_names)
        super.reject { |name| name == ConnectionAdapters::CockroachDBAdapter::DEFAULT_PRIMARY_KEY }
      end

      # Filter out rowid so it doesn't get updated by ActiveRecord. rowid is a
      # column added by CockroachDB for tables that don't define primary keys.
      # CockroachDB will automatically insert rowid values. See
      # https://www.cockroachlabs.com/docs/v19.2/create-table.html#create-a-table.
      def attributes_for_update(attribute_names)
        super.reject { |name| name == ConnectionAdapters::CockroachDBAdapter::DEFAULT_PRIMARY_KEY }
      end
    end
  end

  class Base
    prepend CockroachDB::AttributeMethodsMonkeyPatch
  end
end
