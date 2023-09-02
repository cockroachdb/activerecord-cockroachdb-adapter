exclude :test_set_pk_sequence, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_pk_and_sequence_for_with_schema_specified, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"

# This hack allows us to redefine the
# setup. We are using various weird
# routes that might be simplified:
# 1. We use `Ext` to prepend to the
#    current class to be sure `#setup`
#    is overriden.
# 2. Current is a reference to self to
#    access it in `Ext`
# 3. const_missing is used to avoid
#    having to rewrite every constant.
Current = self
module Ext
  def self.const_missing(const)
    Current.const_get(const)
  end

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.execute "SET default_int_size = 4"
    @connection.execute "SET serial_normalization = sql_sequence_cached"
    @connection.execute "CREATE SCHEMA #{SCHEMA_NAME}"
    @connection.execute "CREATE TABLE #{SCHEMA_NAME}.#{TABLE_NAME} (#{COLUMNS.join(',')})"
    @connection.execute "CREATE TABLE #{SCHEMA_NAME}.\"#{TABLE_NAME}.table\" (#{COLUMNS.join(',')})"
    @connection.execute "CREATE TABLE #{SCHEMA_NAME}.\"#{CAPITALIZED_TABLE_NAME}\" (#{COLUMNS.join(',')})"
    @connection.execute "CREATE SCHEMA #{SCHEMA2_NAME}"
    @connection.execute "CREATE TABLE #{SCHEMA2_NAME}.#{TABLE_NAME} (#{COLUMNS.join(',')})"
    @connection.execute "CREATE INDEX #{INDEX_A_NAME} ON #{SCHEMA_NAME}.#{TABLE_NAME}  USING btree (#{INDEX_A_COLUMN});"
    @connection.execute "CREATE INDEX #{INDEX_A_NAME} ON #{SCHEMA2_NAME}.#{TABLE_NAME}  USING btree (#{INDEX_A_COLUMN});"
    @connection.execute "CREATE INDEX #{INDEX_B_NAME} ON #{SCHEMA_NAME}.#{TABLE_NAME}  USING btree (#{INDEX_B_COLUMN_S1});"
    @connection.execute "CREATE INDEX #{INDEX_B_NAME} ON #{SCHEMA2_NAME}.#{TABLE_NAME}  USING btree (#{INDEX_B_COLUMN_S2});"
    @connection.execute "CREATE INDEX #{INDEX_C_NAME} ON #{SCHEMA_NAME}.#{TABLE_NAME}  USING gin (#{INDEX_C_COLUMN});"
    @connection.execute "CREATE INDEX #{INDEX_C_NAME} ON #{SCHEMA2_NAME}.#{TABLE_NAME}  USING gin (#{INDEX_C_COLUMN});"
    @connection.execute "CREATE INDEX #{INDEX_D_NAME} ON #{SCHEMA_NAME}.#{TABLE_NAME}  USING btree (#{INDEX_D_COLUMN} DESC);"
    @connection.execute "CREATE INDEX #{INDEX_D_NAME} ON #{SCHEMA2_NAME}.#{TABLE_NAME}  USING btree (#{INDEX_D_COLUMN} DESC);"
    @connection.execute "CREATE INDEX #{INDEX_E_NAME} ON #{SCHEMA_NAME}.#{TABLE_NAME}  USING gin (#{INDEX_E_COLUMN});"
    @connection.execute "CREATE INDEX #{INDEX_E_NAME} ON #{SCHEMA2_NAME}.#{TABLE_NAME}  USING gin (#{INDEX_E_COLUMN});"
    @connection.execute "CREATE TABLE #{SCHEMA_NAME}.#{PK_TABLE_NAME} (id serial primary key)"
    @connection.execute "CREATE TABLE #{SCHEMA2_NAME}.#{PK_TABLE_NAME} (id serial primary key)"
    @connection.execute "CREATE SEQUENCE #{SCHEMA_NAME}.#{UNMATCHED_SEQUENCE_NAME}"
    @connection.execute "CREATE TABLE #{SCHEMA_NAME}.#{UNMATCHED_PK_TABLE_NAME} (id integer NOT NULL DEFAULT nextval('#{SCHEMA_NAME}.#{UNMATCHED_SEQUENCE_NAME}'::regclass), CONSTRAINT unmatched_pkey PRIMARY KEY (id))"
  end

  def teardown
    @connection.execute "SET default_int_size = DEFAULT"
    @connection.execute "SET serial_normalization = DEFAULT"
    super
  end
end
prepend Ext
