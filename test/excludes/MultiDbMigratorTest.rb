require "support/copy_cat"

class CockroachDB < MultiDbMigratorTest
	self.use_transactional_tests = false

	CopyCat.copy_methods(self, MultiDbMigratorTest, :test_internal_metadata_stores_environment)
end

exclude :test_internal_metadata_stores_environment, "We can't add " \
	"and remove a column in the same transaction with CockroachDB"
