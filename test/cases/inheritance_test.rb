require "cases/helper_cockroachdb"

# Load dependencies from ActiveRecord test suite
require "models/company"

module CockroachDB
  class InheritanceComputeTypeTest < ActiveRecord::TestCase

    # This replaces the same test that's been excluded from
    # InheritanceComputeTypeTest. New, unsaved records won't have
    # string default values if the default has been changed in the database.
    # This happens because once a column default is changed in CockroachDB, the
    # type information on the value is missing.
    # We can still verify the desired behavior by persisting the test records.
    # When ActiveRecord fetches the records from the database, they'll have
    # their default values.
    # See test/excludes/InheritanceComputeTypeTest.rb
    def test_inheritance_new_with_subclass_as_default
      original_type = Company.columns_hash["type"].default
      ActiveRecord::Base.connection.change_column_default :companies, :type, "Firm"
      Company.reset_column_information

      # Instead of using an unsaved Company record, persist one and fetch it
      # from the database to get the new default value for type.
      Company.create!(name: "Acme Co.", firm_name: "Shri Hans Plastic") # with arguments
      firm = Company.last
      assert_equal "Firm", firm.type
      assert_instance_of Firm, firm

      client = Client.new
      assert_equal "Client", client.type
      assert_instance_of Client, client

      firm = Company.new(type: "Client") # overwrite the default type
      assert_equal "Client", firm.type
      assert_instance_of Client, firm
    ensure
      ActiveRecord::Base.connection.change_column_default :companies, :type, original_type
      Company.reset_column_information
    end
  end
end
