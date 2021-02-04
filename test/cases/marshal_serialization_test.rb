# frozen_string_literal: true

require "cases/helper"
require "models/topic"
require "models/reply"
require "support/paths_cockroachdb"

class MarshalSerializationTest < ActiveRecord::TestCase
  # This test file is identical to the one in Rails, except that
  # the marshal_fixture_path method specifies to use the PostgreSQL
  # directory instead of basing it off of the adapter name.
  fixtures :topics

  def test_deserializing_rails_6_0_marshal_basic
    topic = Marshal.load(marshal_fixture("rails_6_0_topic"))

    assert_not_predicate topic, :new_record?
    assert_equal 1, topic.id
    assert_equal "The First Topic", topic.title
    assert_equal "Have a nice day", topic.content
  end

  def test_deserializing_rails_6_0_marshal_with_loaded_association_cache
    topic = Marshal.load(marshal_fixture("rails_6_0_topic_associations"))

    assert_not_predicate topic, :new_record?
    assert_equal 1, topic.id
    assert_equal "The First Topic", topic.title
    assert_equal "Have a nice day", topic.content
  end

  private
    def marshal_fixture(file_name)
      File.binread(marshal_fixture_path(file_name))
    end

    def marshal_fixture_path(file_name)
      File.expand_path(
        "support/marshal_compatibility_fixtures/PostgreSQL/#{file_name}.dump",
        ARTest::CockroachDB.root_activerecord_test
      )
    end
end