exclude :test_raises_LockWaitTimeout_when_lock_wait_timeout_exceeded, "The test tries to set lock_timeout, but lock_timeout is not supported by CockroachDB."
exclude :test_raises_QueryCanceled_when_canceling_statement_due_to_user_request, "CockroachDB doesn't support pg_cancel_backend()."
