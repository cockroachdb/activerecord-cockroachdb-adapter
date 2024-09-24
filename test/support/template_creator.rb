# frozen_string_literal: true

require 'active_record'
require_relative 'paths_cockroachdb'

module TemplateCreator
  # extend self

  DEFAULT_CONNECTION_HASH = {
    adapter: 'cockroachdb',
    database: 'defaultdb',
    port: 26257,
    user: 'root',
    host: 'localhost'
  }.freeze

  BACKUP_DIR = "nodelocal://self/activerecord-crdb-adapter"

  module_function

  def ar_version
    ActiveRecord.version.version.gsub('.','')
  end

  def version_backup_path
    BACKUP_DIR + "/#{ar_version}"
  end

  def template_db_name
    "activerecord_unittest_template#{ar_version}"
  end

  def connect(connection_hash=nil)
    connection_hash = DEFAULT_CONNECTION_HASH if connection_hash.nil?
    ActiveRecord::Base.establish_connection(connection_hash)
  end

  def template_db_exists?
    ActiveRecord::Base.lease_connection.select_value("SELECT 1 FROM pg_database WHERE datname='#{template_db_name}'") == 1
  end

  def drop_template_db
    ActiveRecord::Base.lease_connection.execute("DROP DATABASE #{template_db_name}")
  end

  def create_template_db
    ActiveRecord::Base.lease_connection.execute("CREATE DATABASE #{template_db_name}")
  end

  def load_schema
    p 'loading schema'
    load ARTest::CockroachDB.root_activerecord_test + '/schema/schema.rb'
    load 'test/schema/cockroachdb_specific_schema.rb'
  end

  def create_test_template
    connect
    raise "#{template_db_name} already exists. If you do not have a backup created, please drop the database and run again." if template_db_exists?

    create_template_db

    # switch connection to template db
    conn = DEFAULT_CONNECTION_HASH.dup
    conn['database'] = template_db_name
    connect(conn)

    load_schema

    # create BACKUP to restore from
    ActiveRecord::Base.lease_connection.execute("BACKUP DATABASE #{template_db_name} TO '#{version_backup_path}'")
  end

  def restore_from_template
    connect
    raise "The TemplateDB does not exist. Run 'rake db:create_test_template' first." unless template_db_exists?

    begin
      ActiveRecord::Base.lease_connection.execute("DROP DATABASE activerecord_unittest")
    rescue ActiveRecord::StatementInvalid => e
      unless e.cause.class == PG::InvalidCatalogName
        raise e
      end
    end
    ActiveRecord::Base.lease_connection.execute("CREATE DATABASE activerecord_unittest")

    ActiveRecord::Base.lease_connection.execute("RESTORE #{template_db_name}.* FROM '#{version_backup_path}' WITH into_db = 'activerecord_unittest'")
  end
end
