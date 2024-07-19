
# > In CRDB SERIALIZABLE, reads block on in-progress writes for
# > as long as those writes are in progress. However, PG does
# > not have this "read block on write" behavior, and so rather
# > than allowing the left-hand-side to execute, it must instead
# > abort that transaction. Both are valid ways to implement SERIALIZABLE.
#
# See discussion: https://github.com/cockroachdb/activerecord-cockroachdb-adapter/pull/333
message = "SERIALIZABLE transactions are different in CockroachDB."

# exclude :test_deadlock_raises_Deadlocked_inside_nested_SavepointTransaction, message
# exclude :test_unserializable_transaction_raises_SerializationFailure_inside_nested_SavepointTransaction, message
exclude :test_SerializationFailure_inside_nested_SavepointTransaction_is_recoverable, message
exclude :test_deadlock_inside_nested_SavepointTransaction_is_recoverable, message
