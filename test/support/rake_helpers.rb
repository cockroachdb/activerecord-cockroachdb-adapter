def env_ar_test_files
  return unless ENV['TEST_FILES_AR'] && !ENV['TEST_FILES_AR'].empty?

  @env_ar_test_files ||= ENV['TEST_FILES_AR'].
    split(',').
    map { |file| File.join ARTest::CockroachDB.root_activerecord, file.strip }.
    sort
end

def ar_cases
  @ar_cases ||= Dir.
    glob("#{ARTest::CockroachDB.root_activerecord}/test/cases/**/*_test.rb").
    reject{ |x| x =~ /\/adapters\/mysql2\// }.
    reject{ |x| x =~ /\/adapters\/sqlite3\// }.
    sort
end

def test_files
  env_ar_test_files || ar_cases
end
