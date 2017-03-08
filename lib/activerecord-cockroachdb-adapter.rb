if defined?(Rails)
  module ActiveRecord
    module ConnectionAdapters
      class CockroachDBRailtie < ::Rails::Railtie
        rake_tasks do
          load "active_record/connection_adapters/cockroachdb/database_tasks.rb"
        end
      end
    end
  end
end
