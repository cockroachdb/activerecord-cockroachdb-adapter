# frozen_string_literal: true

module RakeHelpers
  COCKROACHDB_TEST_HELPER = 'test/cases/helper_cockroachdb.rb'

  module_function

  # Look for TEST_FILES_AR or TEST_FILES env variables
  # to set specific tests, otherwise load every tests
  # from active_record and this adapter.
  def test_files
    ar_test_files = ENV.fetch('TEST_FILES_AR', '')
    cr_test_files = ENV.fetch('TEST_FILES', '')

    return all_test_file if ar_test_files.empty? && cr_test_files.empty?

    ar_test_files = ar_test_files.
      split(',').
      map { |file| File.join ARTest::CockroachDB.root_activerecord, file.strip }.
      then { _1.prepend(COCKROACHDB_TEST_HELPER) unless _1.empty? }.
      prepend(COCKROACHDB_TEST_HELPER)

    cr_test_files = cr_test_files.split(',').map(&:strip)

    ar_test_files + cr_test_files
  end

  def all_test_files
    activerecord_test_files = Dir.
      glob("#{ARTest::CockroachDB.root_activerecord}/test/cases/**/*_test.rb").
      reject { _1.match?(%r(/adapters/(?:mysql2|sqlite3)/) }.
      prepend(COCKROACHDB_TEST_HELPER)

    cockroachdb_test_files = Dir.glob('test/cases/**/*_test.rb')

    activerecord_test_files + cockroachdb_test_files
  end
end
