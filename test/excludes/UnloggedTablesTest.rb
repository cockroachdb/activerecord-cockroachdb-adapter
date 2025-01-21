instance_methods.grep(/\Atest_\w+\z/).each do |method_name|
  exclude method_name, "UNLOGGED has no effect in CockroachDB."
end
