module ActiveRecord
  module Type
    class << self
      # Return :postgresql instead of :cockroachdb for current_adapter_name so
      # we can continue using the ActiveRecord::Types defined in
      # PostgreSQLAdapter.
      def adapter_name_from(_model)
        :postgresql
      end
    end
  end
end
