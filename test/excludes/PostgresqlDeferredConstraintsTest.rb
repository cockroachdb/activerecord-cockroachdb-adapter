instance_methods.grep(/\Atest_/).each do |m|
  exclude m, "CockroachDB doesn't support 'SET CONSTRAINTS ...'"
end
