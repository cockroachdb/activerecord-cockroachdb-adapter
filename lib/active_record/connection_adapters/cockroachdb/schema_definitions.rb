# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      module ColumnMethods
        # Defines the primary key field.
        # Use of the native CockroachDB UUID type is supported, and can be used
        # by defining your tables as such:
        #
        #   create_table :stuffs, id: :uuid do |t|
        #     t.string :content
        #     t.timestamps
        #   end
        #
        # By default, this will use the +uuid_v4()::UUID+ as defined in
        # https://www.cockroachlabs.com/docs/v1.1/uuid.html, which is equivalent of :
        #
        #   create_table :stuffs, id: false do |t|
        #     t.primary_key :id, :uuid, default: "uuid_v4()::UUID"
        #     t.uuid :foo_id
        #     t.timestamps
        #   end
        #
        # You may also pass a custom stored procedure that returns a UUID or use a
        # different UUID generation function from another library.
        #
        # Note that setting the UUID primary key default value to +nil+ will
        # require you to assure that you always provide a UUID value before saving
        # a record (as primary keys cannot be +nil+). This might be done via the
        # +SecureRandom.uuid+ method and a +before_save+ callback, for instance.
        def primary_key(name, type = :primary_key, **options)
          if type == :uuid
            options[:default] = options.fetch(:default, "uuid_v4()::UUID")
          end

          super
        end
      end
    end
  end
end
