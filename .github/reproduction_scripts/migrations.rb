# frozen_string_literal: true
#
# Adapted from https://github.com/rails/rails/blob/main/guides/bug_report_templates/active_record_migrations.rb

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  gem "activerecord"

  gem "activerecord-cockroachdb-adapter"
end

require "activerecord-cockroachdb-adapter"
require "minitest/autorun"
require "logger"

# You might want to change the database name for another one.
ActiveRecord::Base.establish_connection("cockroachdb://root@localhost:26257/defaultdb")
ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Schema.define do
  create_table :payments, force: true do |t|
    t.decimal :amount, precision: 10, scale: 0, default: 0, null: false
  end
end

class Payment < ActiveRecord::Base
end

class ChangeAmountToAddScale < ActiveRecord::Migration::Current # or use a specific version via `Migration[number]`
  def change
    reversible do |dir|
      dir.up do
        change_column :payments, :amount, :decimal, precision: 10, scale: 2
      end

      dir.down do
        change_column :payments, :amount, :decimal, precision: 10, scale: 0
      end
    end
  end
end

class BugTest < ActiveSupport::TestCase
  def test_migration_up
    ChangeAmountToAddScale.migrate(:up)
    Payment.reset_column_information

    assert_equal "decimal(10,2)", Payment.columns.last.sql_type
  end

  def test_migration_down
    ChangeAmountToAddScale.migrate(:down)
    Payment.reset_column_information

    assert_equal "decimal(10)", Payment.columns.last.sql_type
  end
end
