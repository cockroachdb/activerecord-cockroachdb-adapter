module ActiveRecord
  module Type
    module CRDBExt
      # Return :postgresql instead of :cockroachdb for current_adapter_name so
      # we can continue using the ActiveRecord::Types defined in
      # PostgreSQLAdapter.
      def adapter_name_from(model)
        name = super
        return :postgresql if name == :cockroachdb

        name
      end
    end
    singleton_class.prepend CRDBExt
  end
end
