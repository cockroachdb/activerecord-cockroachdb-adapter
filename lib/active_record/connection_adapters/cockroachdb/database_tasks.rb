# frozen_string_literal: true

# Copyright 2024 The Cockroach Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "active_record/base"

module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      class DatabaseTasks < ActiveRecord::Tasks::PostgreSQLDatabaseTasks
        def structure_dump(filename, extra_flags=nil)
          if extra_flags
            raise "No flag supported yet, please raise an issue if needed. " \
              "https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/new"
          end

          # "See https://github.com/cockroachdb/cockroach/issues/26443."
          search_path =
            case ActiveRecord.dump_schemas
            when :schema_search_path
              configuration_hash[:schema_search_path]
            when :all
              nil
            when String
              ActiveRecord.dump_schemas
            end

          conn = ActiveRecord::Base.connection
          begin
            old_search_path = conn.schema_search_path
            conn.schema_search_path = search_path
            File.open(filename, "w") do |file|
              # NOTE: There is no issue with the crdb_internal schema, it is ignored by SHOW CREATE.
              %w(SCHEMAS TYPES).each do |object_kind|
                ActiveRecord::Base.connection.execute("SHOW CREATE ALL #{object_kind}").each_row { file.puts _1 }
              end

              ignore_tables = ActiveRecord::SchemaDumper.ignore_tables.to_set

              conn.execute("SHOW CREATE ALL TABLES").each_row do |(sql)|
                if sql.start_with?("CREATE")
                  table_name = sql[/CREATE TABLE (?:.*?\.)?\"?(.*?)[\" ]/, 1]
                  next if ignore_tables.member?(table_name)
                elsif sql.start_with?("ALTER")
                  table_name = sql[/ALTER TABLE (?:.*?\.)?\"?(.*?)[\" ]/, 1]
                  ref_table_name = sql[/REFERENCES (?:.*?\.)?\"?(.*?)[\" ]/, 1]
                  next if ignore_tables.member?(table_name) || ignore_tables.member?(ref_table_name)
                end

                file.puts sql
              end
              file.puts "SET search_path TO #{conn.schema_search_path};\n\n"
            end
          ensure
            conn.schema_search_path = old_search_path
          end
        end

        def structure_load(filename, extra_flags=nil)
          if extra_flags
            raise "No flag supported yet, please raise an issue if needed. " \
              "https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/new"
          end

          run_cmd("cockroach", ["sql", "--set", "errexit=false", "--file", filename], "loading")
        end

        private

        # Adapted from https://github.com/rails/rails/blob/a5fc471b3/activerecord/lib/active_record/tasks/postgresql_database_tasks.rb#L106.
        # Using https://www.cockroachlabs.com/docs/stable/connection-parameters.html#additional-connection-parameters.
        def cockroach_env
          usr_pwd = ""
          if configuration_hash[:username]
            usr_pwd += configuration_hash[:username].to_s
            if configuration_hash[:password]
              usr_pwd += ":"
              usr_pwd += configuration_hash[:password].to_s
            end
            usr_pwd += "@"
          end

          port = ""
          port = ":#{configuration_hash[:port]}" if configuration_hash[:port]

          params = %i(sslmode sslrootcert sslcert sslkey).filter_map do |key|
            "#{key}=#{configuration_hash[key]}" if configuration_hash[key]
          end.join("&")
          params = "?#{params}" unless params.empty?

          url = "postgres://#{usr_pwd}#{db_config.host}#{port}/#{db_config.database}#{params}"

          {
            # NOTE: sslmode in the url will take precedence over this setting, hence
            #   we don't need to conditionally set it.
            "COCKROACH_INSECURE" => "true",
            "COCKROACH_URL" => url
          }
        end
        # The `#run_cmd` method use `psql_env` to set environments variables.
        # We override it with cockroach env variables.
        alias_method :psql_env, :cockroach_env
      end
    end
  end
end

ActiveRecord::Tasks::DatabaseTasks.register_task(/cockroachdb/, ActiveRecord::ConnectionAdapters::CockroachDB::DatabaseTasks)
