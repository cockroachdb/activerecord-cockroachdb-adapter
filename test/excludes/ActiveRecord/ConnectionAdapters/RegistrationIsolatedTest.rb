exclude "test_#resolve_raises_if_the_adapter_is_using_the_pre_7.2_adapter_registration_API", "One adapter is missing in the test, added below"

test "#resolve raises if the adapter is using the pre 7.2 adapter registration API with CRDB" do
  exception = assert_raises(ActiveRecord::AdapterNotFound) do
    ActiveRecord::ConnectionAdapters.resolve("fake_legacy")
  end

  assert_equal(
    "Database configuration specifies nonexistent 'fake_legacy' adapter. Available adapters are: abstract, cockroachdb, fake, mysql2, postgresql, sqlite3, trilogy. Ensure that the adapter is spelled correctly in config/database.yml and that you've added the necessary adapter gem to your Gemfile if it's not in the list of available adapters.",
    exception.message
  )
ensure
  ActiveRecord::ConnectionAdapters.instance_variable_get(:@adapters).delete("fake_legacy")
end
