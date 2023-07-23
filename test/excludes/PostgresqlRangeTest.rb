message = "CockroachDB doesn't support ranges. See https://github.com/cockroachdb/cockroach/issues/27791"
# No test is relevant in this class.
instance_methods.grep(/\Atest_/).each { exclude _1, message }
