require "cases/helper_cockroachdb"

# Load dependencies from ActiveRecord test suite
require "cases/helper"
require "support/connection_helper"
require "models/account"
require "models/binary"
require "models/category"
require "models/company"
require "models/computer"
require "models/course"
require "models/developer"
require "models/joke"
require "models/parrot"
require "models/pirate"
require "models/task"
require "models/topic"
require "models/traffic_light"
require "models/treasure"

module CockroachDB
  class FixturesTest < ActiveRecord::TestCase
    include ConnectionHelper
    self.use_instantiated_fixtures = true
    self.use_transactional_tests = false

    # other_topics fixture should not be included here
    fixtures :topics, :developers, :accounts, :tasks, :categories, :funny_jokes, :binaries, :traffic_lights

    FIXTURES = %w( accounts binaries companies customers
                  developers developers_projects entrants
                  movies projects subscribers topics tasks )
    MATCH_ATTRIBUTE_NAME = /[a-zA-Z][-\w]*/

    # Drop and recreate the parrots and treasures tables so they use
    # primary key sequences. After recreating the tables, load their fixtures.
    def before_setup
      conn = ActiveRecord::Base.lease_connection

      conn.disable_referential_integrity do
        parrots_redefine
        treasures_redefine
        parrots_pirates_redefine
        parrots_treasures_redefine
      end
    ensure
      super
    end

    def teardown
      Arel::Table.engine = ActiveRecord::Base
    ensure
      super
    end

    # This replaces the same test that's been excluded from
    # FixturesTest. The test is exactly the same, but the tables
    # under test will have primary key sequences, and the connection is from ActiveRecord::Base.
    # Normally, the primary keys would use CockroachDB's unique_rowid().
    def test_clean_fixtures
      FIXTURES.each do |name|
        fixtures = nil
        assert_nothing_raised { fixtures = create_fixtures(name).first }
        assert_kind_of(ActiveRecord::FixtureSet, fixtures)
        fixtures.each { |_name, fixture|
          fixture.each { |key, value|
            assert_match(MATCH_ATTRIBUTE_NAME, key)
          }
        }
      end
    end

    class InsertQuerySubscriber
      attr_reader :events

      def initialize
        @events = []
      end

      def call(_, _, _, _, values)
        @events << values[:sql] if values[:sql] =~ /INSERT/
      end
    end

    # This replaces the same test that's been excluded from
    # FixturesTest. The test is exactly the same, but the tables
    # under test will have primary key sequences, and the connection is from ActiveRecord::Base.
    # Normally, the primary keys would use CockroachDB's unique_rowid().
    def test_auto_value_on_primary_key
      fixtures = [
        { "name" => "first", "wheels_count" => 2 },
        { "name" => "second", "wheels_count" => 3 }
      ]
      conn = ActiveRecord::Base.lease_connection
      assert_nothing_raised do
        conn.insert_fixtures_set({ "aircraft" => fixtures }, ["aircraft"])
      end
      result = conn.select_all("SELECT name, wheels_count FROM aircraft ORDER BY id")
      assert_equal fixtures, result.to_a
    end

    # This replaces the same test that's been excluded from
    # FixturesTest. The test is exactly the same, but the tables
    # under test will have primary key sequences, and the connection is from ActiveRecord::Base.
    # Normally, the primary keys would use CockroachDB's unique_rowid().
    def test_create_fixtures
      fixtures = ActiveRecord::FixtureSet.create_fixtures(FIXTURES_ROOT, "parrots")
      assert Parrot.find_by_name("Curious George"), "George is not in the database"
      assert fixtures.detect { |f| f.name == "parrots" }, "no fixtures named 'parrots' in #{fixtures.map(&:name).inspect}"
    end

    # This replaces the same test that's been excluded from
    # FixturesTest. The test is exactly the same, but the tables
    # under test will have primary key sequences, and the connection is from ActiveRecord::Base.
    # Normally, the primary keys would use CockroachDB's unique_rowid().
    def test_multiple_clean_fixtures
      fixtures_array = nil
      assert_nothing_raised { fixtures_array = create_fixtures(*FIXTURES) }
      assert_kind_of(Array, fixtures_array)
      fixtures_array.each { |fixtures| assert_kind_of(ActiveRecord::FixtureSet, fixtures) }
    end

    # This replaces the same test that's been excluded from
    # FixturesTest. The test is exactly the same, but the tables
    # under test will have primary key sequences, and the connection is from ActiveRecord::Base.
    # Normally, the primary keys would use CockroachDB's unique_rowid().
    def test_bulk_insert_with_a_multi_statement_query_raises_an_exception_when_any_insert_fails
      require "models/aircraft"

      assert_equal false, Aircraft.columns_hash["wheels_count"].null
      fixtures = {
        "aircraft" => [
          { "name" => "working_aircrafts", "wheels_count" => 2 },
          { "name" => "broken_aircrafts", "wheels_count" => nil },
        ]
      }

      assert_no_difference "Aircraft.count" do
        assert_raises(ActiveRecord::NotNullViolation) do
          ActiveRecord::Base.lease_connection.insert_fixtures_set(fixtures)
        end
      end
    end

    # This replaces the same test that's been excluded from
    # FixturesTest. The test is exactly the same, but the tables
    # under test will have primary key sequences, and the connection is from ActiveRecord::Base.
    # Normally, the primary keys would use CockroachDB's unique_rowid().
    def test_inserts_with_pre_and_suffix
      # Reset cache to make finds on the new table work
      ActiveRecord::FixtureSet.reset_cache

      ActiveRecord::Base.lease_connection.create_table :prefix_other_topics_suffix do |t|
        t.column :title, :string
        t.column :author_name, :string
        t.column :author_email_address, :string
        t.column :written_on, :datetime
        t.column :bonus_time, :time
        t.column :last_read, :date
        t.column :content, :string
        t.column :approved, :boolean, default: true
        t.column :replies_count, :integer, default: 0
        t.column :parent_id, :integer
        t.column :type, :string, limit: 50
      end

      # Store existing prefix/suffix
      old_prefix = ActiveRecord::Base.table_name_prefix
      old_suffix = ActiveRecord::Base.table_name_suffix

      # Set a prefix/suffix we can test against
      ActiveRecord::Base.table_name_prefix = "prefix_"
      ActiveRecord::Base.table_name_suffix = "_suffix"

      other_topic_klass = Class.new(ActiveRecord::Base) do
        def self.name
          "OtherTopic"
        end
      end

      topics = [create_fixtures("other_topics")].flatten.first

      # This checks for a caching problem which causes a bug in the fixtures
      # class-level configuration helper.
      assert_not_nil topics, "Fixture data inserted, but fixture objects not returned from create"

      first_row = ActiveRecord::Base.lease_connection.select_one("SELECT * FROM prefix_other_topics_suffix WHERE author_name = 'David'")
      assert_not_nil first_row, "The prefix_other_topics_suffix table appears to be empty despite create_fixtures: the row with author_name = 'David' was not found"
      assert_equal("The First Topic", first_row["title"])

      second_row = ActiveRecord::Base.lease_connection.select_one("SELECT * FROM prefix_other_topics_suffix WHERE author_name = 'Mary'")
      assert_nil(second_row["author_email_address"])

      assert_equal :prefix_other_topics_suffix, topics.table_name.to_sym
      # This assertion should preferably be the last in the list, because calling
      # other_topic_klass.table_name sets a class-level instance variable
      assert_equal :prefix_other_topics_suffix, other_topic_klass.table_name.to_sym

    ensure
      # Restore prefix/suffix to its previous values
      ActiveRecord::Base.table_name_prefix = old_prefix
      ActiveRecord::Base.table_name_suffix = old_suffix

      ActiveRecord::Base.lease_connection.drop_table :prefix_other_topics_suffix, if_exists: true
    end

    # This replaces the same test that's been excluded from
    # FixturesTest. The test is exactly the same, but the tables
    # under test will have primary key sequences, and the connection is from ActiveRecord::Base.
    # Normally, the primary keys would use CockroachDB's unique_rowid().
    def test_create_symbol_fixtures
      fixtures = ActiveRecord::FixtureSet.create_fixtures(FIXTURES_ROOT, :collections, collections: Course)

      assert Course.find_by_name("Collection"), "course is not in the database"
      assert fixtures.detect { |f| f.name == "collections" }, "no fixtures named 'collections' in #{fixtures.map(&:name).inspect}"
    end

    private

    def parrots_redefine
      Parrot.lease_connection.exec_query("DROP TABLE IF EXISTS parrots_pirates")
      Parrot.lease_connection.exec_query("DROP TABLE IF EXISTS parrots_treasures")

      Parrot.lease_connection.drop_table :parrots, if_exists: true

      Parrot.lease_connection.exec_query("CREATE SEQUENCE IF NOT EXISTS parrots_id_seq")
      Parrot.lease_connection.exec_query("
        CREATE TABLE parrots (
          id INT PRIMARY KEY DEFAULT nextval('parrots_id_seq'),
          breed INT DEFAULT 0,
          name VARCHAR NULL,
          color VARCHAR NULL,
          parrot_sti_class VARCHAR NULL,
          killer_id INT8 NULL,
          updated_count INT8 NULL DEFAULT 0:::INT8,
          created_at TIMESTAMP NULL,
          created_on TIMESTAMP NULL,
          updated_at TIMESTAMP NULL,
          updated_on TIMESTAMP NULL
        )
      ")
    end

    def parrots_pirates_redefine
      Parrot.lease_connection.exec_query("DROP TABLE IF EXISTS parrots_pirates")
      Parrot.lease_connection.exec_query("
          CREATE TABLE parrots_pirates (
            parrot_id INT8 NULL,
            pirate_id INT8 NULL,
            CONSTRAINT fk_parrot_id FOREIGN KEY (parrot_id) REFERENCES parrots(id),
            CONSTRAINT fk_pirate_id FOREIGN KEY (pirate_id) REFERENCES pirates(id)
          )
        ")
    end

    def treasures_redefine
      Treasure.lease_connection.drop_table :treasures, if_exists: true

      Treasure.lease_connection.exec_query("CREATE SEQUENCE IF NOT EXISTS treasures_id_seq")
      Treasure.lease_connection.exec_query("
        CREATE TABLE treasures (
          id INT PRIMARY KEY DEFAULT nextval('treasures_id_seq'),
          name VARCHAR NULL,
          type VARCHAR NULL,
          looter_type VARCHAR NULL,
          looter_id INT8 NULL,
          ship_id INT8 NULL
        )
      ")
    end

    def parrots_treasures_redefine
      Parrot.lease_connection.exec_query("DROP TABLE IF EXISTS parrots_treasures")
      Parrot.lease_connection.exec_query("
          CREATE TABLE parrots_treasures (
            parrot_id INT8 NULL,
            treasure_id INT8 NULL
          )
        ")
    end
  end

  class FixturesResetPkSequenceTest < ActiveRecord::TestCase
    self.use_transactional_tests = false

    # Drop and recreate the accounts, companies, and courses tables so they use
    # primary key sequences. After recreating the tables, load their fixtures.
    # We'll do this in a before_setup so we get ahead of
    # ActiveRecord::TestFixtures#before_setup.
    def before_setup
      Account.lease_connection.drop_table :accounts, if_exists: true
      Account.lease_connection.exec_query("CREATE SEQUENCE IF NOT EXISTS accounts_id_seq")
      Account.lease_connection.exec_query("
        CREATE TABLE accounts (
          id BIGINT PRIMARY KEY DEFAULT nextval('accounts_id_seq'),
          created_at timestamp NULL,
          updated_at timestamp NULL,
          firm_id bigint,
          firm_name character varying,
          credit_limit integer,
          status string,
          #{'a' * max_identifier_length} integer
        )
      ")

      Company.lease_connection.drop_table :companies, if_exists: true
      Company.lease_connection.exec_query("CREATE SEQUENCE IF NOT EXISTS companies_nonstd_seq")
      Company.lease_connection.exec_query("
        CREATE TABLE companies (
          id BIGINT PRIMARY KEY DEFAULT nextval('companies_nonstd_seq'),
          type character varying,
          firm_id bigint,
          firm_name character varying,
          name character varying,
          client_of bigint,
          rating bigint,
          account_id integer,
          description character varying,
          status integer
        )
      ")

      Course.lease_connection.drop_table :courses, if_exists: true
      Course.lease_connection.exec_query("CREATE SEQUENCE IF NOT EXISTS courses_id_seq")
      Course.lease_connection.exec_query("
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
      Account.lease_connection.drop_table :accounts, if_exists: true
      Account.lease_connection.exec_query("DROP SEQUENCE IF EXISTS accounts_id_seq")
      Account.lease_connection.create_table :accounts, force: true do |t|
        t.timestamps null: true
        t.references :firm, index: false
        t.string  :firm_name
        t.integer :credit_limit
        t.string :status
        t.integer "a" * max_identifier_length
      end

      Company.lease_connection.drop_table :companies, if_exists: true
      Company.lease_connection.exec_query("DROP SEQUENCE IF EXISTS companies_nonstd_seq CASCADE")
      Company.lease_connection.create_table :companies, force: true do |t|
        t.string :type
        t.references :firm, index: false
        t.string  :firm_name
        t.string  :name
        t.bigint :client_of
        t.bigint :rating, default: 1
        t.integer :account_id
        t.string :description, default: ""
        t.integer :status, default: 0
        t.index [:name, :rating], order: :desc
        t.index [:name, :description], length: 10
        t.index [:firm_id, :type, :rating], name: "company_index", length: { type: 10 }, order: { rating: :desc }
        t.index [:firm_id, :type], name: "company_partial_index", where: "(rating > 10)"
        t.index [:firm_id], name: "company_nulls_not_distinct", nulls_not_distinct: true
        t.index :name, name: "company_name_index", using: :btree
        t.index "(CASE WHEN rating > 0 THEN lower(name) END) DESC", name: "company_expression_index" if Company.lease_connection.supports_expression_index?
        t.index [:firm_id, :type], name: "company_include_index", include: [:name, :account_id]
      end

      Course.lease_connection.drop_table :courses, if_exists: true
      Course.lease_connection.exec_query("DROP SEQUENCE IF EXISTS courses_id_seq")
      Course.lease_connection.create_table :courses, force: true do |t|
        t.column :name, :string, null: false
        t.column :college_id, :integer, index: true
      end

      recreate_parrots
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
        model.lease_connection.reset_pk_sequence!(model.table_name, model.primary_key, model.sequence_name)

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
        model.lease_connection.reset_pk_sequence!(model.table_name)

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

    private

    def max_identifier_length
      ActiveRecord::Base.lease_connection.index_name_length
    end

    def recreate_parrots
      conn = ActiveRecord::Base.lease_connection
      conn.disable_referential_integrity do
        conn.drop_table :parrots_pirates, if_exists: true
        conn.drop_table :parrots_treasures, if_exists: true
        conn.drop_table :parrots, if_exists: true

        conn.create_table :parrots, force: :cascade do |t|
          t.string :name
          t.integer :breed, default: 0
          t.string :color
          t.string :parrot_sti_class
          t.integer :killer_id
          t.integer :updated_count, :integer, default: 0
          t.datetime :created_at
          t.datetime :created_on
          t.datetime :updated_at
          t.datetime :updated_on
        end

        conn.create_table :parrots_pirates, id: false, force: true do |t|
          t.references :parrot, foreign_key: true
          t.references :pirate, foreign_key: true
        end

        conn.create_table :parrots_treasures, id: false, force: true do |t|
          t.references :parrot, foreign_key: true
          t.references :treasure, foreign_key: true
        end
      end
    end
  end


  class FkObjectToPointTo < ActiveRecord::Base
    has_many :fk_pointing_to_non_existent_objects
  end
  class FkPointingToNonExistentObject < ActiveRecord::Base
    belongs_to :fk_object_to_point_to
  end

  class FixturesWithForeignKeyViolationsTest < ActiveRecord::TestCase
    # FIXME
    # Spent a long time trying to debug why this only works when the activerecord fixtures_test is run first.
    # The problem is that the fixture is defined in singular "fk_object_to_point_to"
    # but most fixtures are plural (i.e. "parrots"). In the postgres adapter this is handled properly
    # and it pluralizes the table name in the fixture creation step, but in this adapter that doesn't happen.
    # I tried creating a new fixture that was just the pluralized version of this fk_object_to_point_to,
    # but that still didn't work. I tried playing around with ActiveRecord pluralization
    # settings and that didn't work, so for now I'm just going to skip this.
    #
    # Given that this works when the activerecord tests are run first, it's safe to assume
    # this isn't a bug on our end, but it is flakey and will cause the CI to fail depending on the
    # order of tests.
    self.use_instantiated_fixtures = true
    self.use_transactional_tests = false

    def before_setup
      skip("This test will pass only if the activerecord fixtures_test.rb file is run. When it's not run there's an issue where the fixture table name is not pluralized.")
    end

    fixtures :fk_object_to_point_to

    def setup
      # other tests in this file load the parrots fixture but not the treasure one (see `test_create_fixtures`).
      # this creates FK violations since Parrot and ParrotTreasure records are created.
      # those violations can cause false positives in these tests. since they aren't related to these tests we
      # delete the irrelevant records here (this test is transactional so it's fine).
      Parrot.all.each(&:destroy)
    end

    def test_raises_fk_violations
      fk_pointing_to_non_existent_object = <<~FIXTURE
      first:
        fk_object_to_point_to: one
      FIXTURE
      File.write(FIXTURES_ROOT + "/fk_pointing_to_non_existent_object.yml", fk_pointing_to_non_existent_object)

      with_verify_foreign_keys_for_fixtures do
        if current_adapter?(:SQLite3Adapter, :PostgreSQLAdapter, :CockroachDBAdapter)
          assert_raise RuntimeError do
            ActiveRecord::FixtureSet.create_fixtures(FIXTURES_ROOT, ["fk_pointing_to_non_existent_object"])
          end
        else
          assert_nothing_raised do
            ActiveRecord::FixtureSet.create_fixtures(FIXTURES_ROOT, ["fk_pointing_to_non_existent_object"])
          end
        end
      end

    ensure
      File.delete(FIXTURES_ROOT + "/fk_pointing_to_non_existent_object.yml")
      ActiveRecord::FixtureSet.reset_cache
    end

    def test_does_not_raise_if_no_fk_violations
      fk_pointing_to_valid_object = <<~FIXTURE
      first:
        fk_object_to_point_to_id: 1
      FIXTURE
      File.write(FIXTURES_ROOT + "/fk_pointing_to_non_existent_object.yml", fk_pointing_to_valid_object)

      with_verify_foreign_keys_for_fixtures do
        assert_nothing_raised do
          ActiveRecord::FixtureSet.create_fixtures(FIXTURES_ROOT, ["fk_pointing_to_non_existent_object"])
        end
      end

    ensure
      File.delete(FIXTURES_ROOT + "/fk_pointing_to_non_existent_object.yml")
      ActiveRecord::FixtureSet.reset_cache
    end

    private
      def with_verify_foreign_keys_for_fixtures
        setting_was = ActiveRecord.verify_foreign_keys_for_fixtures
        ActiveRecord.verify_foreign_keys_for_fixtures = true
        yield
      ensure
        ActiveRecord.verify_foreign_keys_for_fixtures = setting_was
      end
  end
end
