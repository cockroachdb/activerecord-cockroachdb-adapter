require "cases/helper_cockroachdb"

# Load dependencies from ActiveRecord test suite
require "models/account"
require "models/company"
require "models/course"

module CockroachDB
  class FixturesResetPkSequenceTest < ActiveRecord::TestCase
    self.use_transactional_tests = false

    # Drop and recreate the accounts, companies, and courses tables so they use
    # primary key sequences. After recreating the tables, load their fixtures.
    # We'll do this in a before_setup so we get ahead of
    # ActiveRecord::TestFixtures#before_setup.
    def before_setup
      Account.connection.drop_table :accounts, if_exists: true
      Account.connection.exec_query("CREATE SEQUENCE accounts_id_seq")
      Account.connection.exec_query("
        CREATE TABLE accounts (
          id BIGINT PRIMARY KEY DEFAULT nextval('accounts_id_seq'),
          firm_id bigint,
          firm_name character varying,
          credit_limit integer
        )
      ")

      Company.connection.drop_table :companies, if_exists: true
      Company.connection.exec_query("CREATE SEQUENCE companies_nonstd_seq")
      Company.connection.exec_query("
        CREATE TABLE companies (
          id BIGINT PRIMARY KEY DEFAULT nextval('companies_nonstd_seq'),
          type character varying,
          firm_id bigint,
          firm_name character varying,
          name character varying,
          client_of bigint,
          rating bigint,
          account_id integer,
          description character varying
        )
      ")

      Course.connection.drop_table :courses, if_exists: true
      Course.connection.exec_query("CREATE SEQUENCE courses_id_seq")
      Course.connection.exec_query("
        CREATE TABLE courses (
          id INT PRIMARY KEY DEFAULT nextval('courses_id_seq'),
          name character varying,
          college_id integer
        )
      ")

      self.class.fixtures :accounts
      self.class.fixtures :companies
      self.class.fixtures :courses
    end

    def setup
      @instances = [Account.new(credit_limit: 50), Company.new(name: "RoR Consulting"), Course.new(name: "Test")]
      ActiveRecord::FixtureSet.reset_cache # make sure tables get reinitialized
    end

    # Drop the primary key sequences and bring back the original tables.
    def teardown
      Account.connection.drop_table :accounts, if_exists: true
      Account.connection.exec_query("DROP SEQUENCE IF EXISTS accounts_id_seq")
      Account.connection.create_table :accounts, force: true do |t|
        t.references :firm, index: false
        t.string  :firm_name
        t.integer :credit_limit
      end

      Company.connection.drop_table :companies, if_exists: true
      Company.connection.exec_query("DROP SEQUENCE IF EXISTS companies_nonstd_seq")
      Company.connection.create_table :companies, force: true do |t|
        t.string  :type
        t.references :firm, index: false
        t.string  :firm_name
        t.string  :name
        t.bigint :client_of
        t.bigint :rating, default: 1
        t.integer :account_id
        t.string :description, default: ""
        t.index [:name, :rating], order: :desc
        t.index [:name, :description], length: 10
        t.index [:firm_id, :type, :rating], name: "company_index", length: { type: 10 }, order: { rating: :desc }
        t.index [:firm_id, :type], name: "company_partial_index", where: "(rating > 10)"
        t.index :name, name: "company_name_index", using: :btree
        t.index "(CASE WHEN rating > 0 THEN lower(name) END)", name: "company_expression_index" if Company.connection.supports_expression_index?
      end

      Course.connection.drop_table :courses, if_exists: true
      Course.connection.exec_query("DROP SEQUENCE IF EXISTS courses_id_seq")
      Course.connection.create_table :courses, force: true do |t|
        t.column :name, :string, null: false
        t.column :college_id, :integer
      end
    end

    # This replaces the same test that's been excluded from
    # FixturesResetPkSequenceTest. The test is exactly the same, but the tables
    # under test will have primary key sequences. Normally, the primary keys
    # would use CockroachDB's unique_rowid().
    # See test/excludes/FixturesResetPkSequenceTest.rb
    def test_resets_to_min_pk_with_specified_pk_and_sequence
      @instances.each do |instance|
        model = instance.class
        model.delete_all
        model.connection.reset_pk_sequence!(model.table_name, model.primary_key, model.sequence_name)

        instance.save!
        assert_equal 1, instance.id, "Sequence reset for #{model.table_name} failed."
      end
    end

    # This replaces the same test that's been excluded from
    # FixturesResetPkSequenceTest. The test is exactly the same, but the tables
    # under test will have primary key sequences. Normally, the primary keys
    # would use CockroachDB's unique_rowid().
    # See test/excludes/FixturesResetPkSequenceTest.rb
    def test_resets_to_min_pk_with_default_pk_and_sequence
      @instances.each do |instance|
        model = instance.class
        model.delete_all
        model.connection.reset_pk_sequence!(model.table_name)

        instance.save!
        assert_equal 1, instance.id, "Sequence reset for #{model.table_name} failed."
      end
    end

    # This replaces the same test that's been excluded from
    # FixturesResetPkSequenceTest. The test is exactly the same, but the tables
    # under test will have primary key sequences. Normally, the primary keys
    # would use CockroachDB's unique_rowid().
    # See test/excludes/FixturesResetPkSequenceTest.rb
    def test_create_fixtures_resets_sequences_when_not_cached
      @instances.each do |instance|
        max_id = create_fixtures(instance.class.table_name).first.fixtures.inject(0) do |_max_id, (_, fixture)|
          fixture_id = fixture["id"].to_i
          fixture_id > _max_id ? fixture_id : _max_id
        end

        # Clone the last fixture to check that it gets the next greatest id.
        instance.save!
        assert_equal max_id + 1, instance.id, "Sequence reset for #{instance.class.table_name} failed."
      end
    end
  end
end
