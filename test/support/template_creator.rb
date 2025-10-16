# frozen_string_literal: true

require "activerecord-cockroachdb-adapter"
require_relative 'paths_cockroachdb'
require 'support/config' # ARTest.config
require 'support/connection' # ARTest.connect

module TemplateCreator
  class DefaultDB < ActiveRecord::Base
    establish_connection(
      adapter: 'cockroachdb',
      database: 'defaultdb',
      port: 26257,
      user: 'root',
      host: 'localhost'
    )
  end

  # Database created once the backup is finished to make sure we have a
  # clean backup to work with. See #template_exists?
  EXISTS = "exists"
  BACKUP_DIR = "userfile://defaultdb.public/activerecord-crdb-adapter"

  module_function

  def template_version
    ar_version = ActiveRecord.version.version.gsub('.','_')
    main_schema_digest = Digest::MD5.file(SCHEMA_ROOT + "/schema.rb").hexdigest
    crdb_schema_digest = Digest::MD5.file("#{__dir__}/../schema/cockroachdb_specific_schema.rb").hexdigest
    "#{ar_version}_#{main_schema_digest}_#{crdb_schema_digest}"
  end

  def version_backup_path
    BACKUP_DIR + "/#{template_version}"
  end

  def template_db_name(db_name)
    "#{db_name}__template__#{template_version}"
  end

  def template_exists?
    template_db_exists?(EXISTS)
  end

  def databases
    @databases ||=ARTest.config.dig("connections", "cockroachdb").map { |_, value| value["database"] }.uniq
  end

  def with_template_db_names
    old_crdb = ARTest.config["connections"]["cockroachdb"]
    new_crdb = old_crdb.transform_values { _1.merge("database" => template_db_name(_1["database"])) }
    ARTest.config["connections"]["cockroachdb"] = new_crdb
    yield
  ensure
    ARTest.config["connections"]["cockroachdb"] = old_crdb
  end

  def template_db_exists?(db_name)
    DefaultDB.lease_connection.select_value("SELECT 1 FROM pg_database WHERE datname='#{template_db_name(db_name)}'") == 1
  end

  def drop_template_db(db_name)
    DefaultDB.lease_connection.execute("DROP DATABASE #{template_db_name(db_name)} CASCADE")
  end

  def create_template_db(db_name)
    DefaultDB.lease_connection.execute("CREATE DATABASE #{template_db_name(db_name)}")
  end

  def create_test_template(&block)
    databases.each do |db_name|
      drop_template_db(db_name) if template_db_exists?(db_name)
      create_template_db(db_name)
    end

    with_template_db_names do
      shh { ARTest.connect }
      block.call
    end

    DefaultDB.lease_connection.execute(<<~SQL)
    BACKUP DATABASE #{databases.map { |db| template_db_name(db) }.join(', ')}
    INTO '#{version_backup_path}'
    SQL
    create_template_db(EXISTS)
  end

  def load_from_template(&block)
    create_test_template(&block) unless template_exists?
    databases.each do |db_name|
      begin
        DefaultDB.lease_connection.execute("DROP DATABASE #{db_name}")
      rescue ActiveRecord::StatementInvalid => e
        unless e.cause.class == PG::InvalidCatalogName
          raise e
        end
      end
      DefaultDB.lease_connection.execute("CREATE DATABASE #{db_name}")
      DefaultDB.lease_connection.execute(<<~SQL)
      RESTORE #{template_db_name(db_name)}.*
      FROM LATEST IN '#{version_backup_path}'
      WITH into_db = '#{db_name}'
      SQL
    end
  end

  private def shh
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = original_stdout
  end
end
