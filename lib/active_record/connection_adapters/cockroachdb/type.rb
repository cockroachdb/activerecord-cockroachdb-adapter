module ActiveRecord
  module Type
    class << self
      # Return :postgresql instead of :cockroachdb for current_adapter_name so
      # we can continue using the ActiveRecord::Types defined in
      # PostgreSQLAdapter.
      def adapter_name_from(model)
        name = model.connection_db_config.adapter.to_sym
        return :postgresql if name == :cockroachdb

        name
      end
    end
  end
end
