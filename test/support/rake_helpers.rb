COCKROACHDB_TEST_HELPER = 'test/cases/helper_cockroachdb'

def test_files
  env_activerecord_test_files ||
    env_cockroachdb_test_files ||
    only_activerecord_test_files ||
    only_cockroachdb_test_files ||
    all_test_files
end

def env_activerecord_test_files
  return unless ENV['TEST_FILES_AR'] && !ENV['TEST_FILES_AR'].empty?

  @env_ar_test_files ||= ENV['TEST_FILES_AR'].
    split(',').
    map { |file| File.join ARTest::CockroachDB.root_activerecord, file.strip }.
    sort.
    prepend(COCKROACHDB_TEST_HELPER)
end

def env_cockroachdb_test_files
  return unless ENV['TEST_FILES'] && !ENV['TEST_FILES'].empty?

  @env_test_files ||= ENV['TEST_FILES'].split(',').map(&:strip)
end

def only_activerecord_test_files
  return unless ENV['ONLY_TEST_AR']
  activerecord_test_files
end

def only_cockroachdb_test_files
  return unless ENV['ONLY_TEST_COCKROACHDB']
  cockroachdb_test_files
end

def all_test_files
  activerecord_test_files + cockroachdb_test_files
end

def activerecord_test_files
  Dir.
    glob("#{ARTest::CockroachDB.root_activerecord}/test/cases/**/*_test.rb").
    reject{ |x| x =~ /\/adapters\/mysql2\// }.
    reject{ |x| x =~ /\/adapters\/sqlite3\// }.
    sort.
    prepend(COCKROACHDB_TEST_HELPER)
end

def cockroachdb_test_files
  Dir.glob('test/cases/**/*_test.rb')
end
