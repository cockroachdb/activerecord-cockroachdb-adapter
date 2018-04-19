# frozen_string_literal: true
# NOTE(joey): This is cradled from connection_adapters/postgresql/referential_integrity.rb
# It is commonly used for setting up fixtures during tests.
module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      module ReferentialIntegrity # :nodoc:
        def disable_referential_integrity # :nodoc:
          original_exception = nil
          fkeys = nil

          begin
            transaction do
              tables.each do |table_name|
                fkeys = foreign_keys(table_name)
                fkeys.each do |fkey|
                  remove_foreign_key table_name, name: fkey.options[:name]
                end
              end
            end
          rescue ActiveRecord::ActiveRecordError => e
            original_exception = e
          end

          begin
            yield
          rescue ActiveRecord::InvalidForeignKey => e
            warn <<-WARNING
WARNING: Rails was not able to disable referential integrity.

Please go to https://github.com/cockroachdb/activerecord-cockroachdb-adapter
and report this issue.

    cause: #{original_exception.try(:message)}

              WARNING
            raise e
          end

          begin
            transaction do
              if !fkeys.nil?
                 fkeys.each do |fkey|
                  add_foreign_key fkey.from_table, fkey.to_table, fkey.options
                end
              end
            end
          rescue ActiveRecord::ActiveRecordError
          end
        end
      end
    end
  end
end
