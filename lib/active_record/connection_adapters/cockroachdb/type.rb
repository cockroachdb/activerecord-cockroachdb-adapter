module ActiveRecord
  module Type
    class << self
      private

      # Return :postgresql instead of :cockroachdb for current_adapter_name so
      # we can continue using the ActiveRecord::Types defined in
      # PostgreSQLAdapter.
      def current_adapter_name
        :postgresql
      end
    end
  end
end
