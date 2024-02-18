-- https://www.cockroachlabs.com/docs/stable/local-testing.html
SET CLUSTER SETTING kv.range_merge.queue_interval = '50ms';
SET CLUSTER SETTING jobs.registry.interval.gc = '30s';
SET CLUSTER SETTING jobs.registry.interval.cancel = '180s';
SET CLUSTER SETTING jobs.retention_time = '15s';
SET CLUSTER SETTING sql.stats.automatic_collection.enabled = false;
SET CLUSTER SETTING kv.range_split.by_load_merge_delay = '5s';
ALTER RANGE default CONFIGURE ZONE USING "gc.ttlseconds" = 600;
ALTER DATABASE system CONFIGURE ZONE USING "gc.ttlseconds" = 600;

CREATE DATABASE activerecord_unittest;
CREATE DATABASE activerecord_unittest2;

SET CLUSTER SETTING sql.stats.automatic_collection.enabled = false;
SET CLUSTER SETTING sql.stats.histogram_collection.enabled = false;

SET CLUSTER SETTING sql.defaults.experimental_alter_column_type.enabled = 'true';
SET CLUSTER SETTING sql.defaults.experimental_temporary_tables.enabled = 'true';
