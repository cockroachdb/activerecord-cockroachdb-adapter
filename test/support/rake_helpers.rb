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

    return all_test_files if ar_test_files.empty? && cr_test_files.empty?

    ar_test_files = ar_test_files.
      split(',').
      map { |file| File.join ARTest::CockroachDB.root_activerecord, file.strip }.
      tap { _1.prepend(COCKROACHDB_TEST_HELPER) unless _1.empty? }

    cr_test_files = cr_test_files.split(',').map(&:strip)

    ar_test_files + cr_test_files
  end

  def all_test_files
    activerecord_test_files =
      FileList["#{ARTest::CockroachDB.root_activerecord}/test/cases/**/*_test.rb"].
      reject { _1.include?("/adapters/") || _1.include?("/encryption/performance") } +
      FileList["#{ARTest::CockroachDB.root_activerecord}/test/cases/adapters/postgresql/**/*_test.rb"]

    cockroachdb_test_files = FileList['test/cases/**/*_test.rb']

    FileList[COCKROACHDB_TEST_HELPER] + activerecord_test_files + cockroachdb_test_files
  end
end
