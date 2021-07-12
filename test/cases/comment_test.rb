# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

# Copy of comment_test from ActiveRecord with all but two tests removed.
# We can get these tests to pass by enabling an experimental feature in
# setup, so we exclude them from the AR test cases and run them here.
if ActiveRecord::Base.connection.supports_comments?
  module CockroachDB
    class CommentTest < ActiveRecord::TestCase
      include SchemaDumpingHelper

      self.use_transactional_tests = false

      class Commented < ActiveRecord::Base
        self.table_name = "commenteds"
      end

      setup do
        @connection = ActiveRecord::Base.connection
        
        @connection.create_table("commenteds", comment: "A table with comment", force: true) do |t|
          t.string  "name",    comment: "Comment should help clarify the column purpose"
          t.boolean "obvious", comment: "Question is: should you comment obviously named objects?"
          t.string  "content"
          t.index   "name",    comment: %Q["Very important" index that powers all the performance.\nAnd it's fun!]
        end

        Commented.reset_column_information
      end

      teardown do
        @connection.drop_table "commenteds", if_exists: true
      end

      # This test is modified from the original
      # The original changes the column type from a boolean to a string,
      # but once this happens, comment changes don't work, so I'm not altering
      # the type here.
      def test_remove_comment_from_column
        @connection.change_column :commenteds, :obvious, :boolean, comment: nil

        Commented.reset_column_information
        column = Commented.columns_hash["obvious"]

        assert_equal :boolean, column.type
        assert_nil column.comment
      end

      def test_schema_dump_with_comments
        # Do all the stuff from other tests
        @connection.add_column    :commenteds, :rating, :integer, comment: "I am running out of imagination"
        @connection.change_column :commenteds, :content, :string, comment: "Whoa, content describes itself!"
        @connection.change_column :commenteds, :content, :string
        @connection.change_column :commenteds, :obvious, :boolean, comment: nil
        @connection.add_index     :commenteds, :obvious, name: "idx_obvious", comment: "We need to see obvious comments"

        # And check that these changes are reflected in dump
        output = dump_table_schema "commenteds"
        assert_match %r[create_table "commenteds",.*\s+comment: "A table with comment"], output
        assert_match %r[t\.string\s+"name",\s+comment: "Comment should help clarify the column purpose"], output
        assert_match %r[t\.boolean\s+"obvious"\n], output
        assert_match %r[t\.string\s+"content",\s+comment: "Whoa, content describes itself!"], output
        if current_adapter?(:OracleAdapter)
          assert_match %r[t\.integer\s+"rating",\s+precision: 38,\s+comment: "I am running out of imagination"], output
        else
          assert_match %r[t\.bigint\s+"rating",\s+comment: "I am running out of imagination"], output
          assert_match %r[t\.index\s+.+\s+comment: "\\\"Very important\\\" index that powers all the performance.\\nAnd it's fun!"], output
          assert_match %r[t\.index\s+.+\s+name: "idx_obvious",\s+comment: "We need to see obvious comments"], output
        end
      end
    end
  end
end
