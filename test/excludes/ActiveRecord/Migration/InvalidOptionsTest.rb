module Ext
  def invalid_add_column_option_exception_message(key)
    default_keys = [":limit", ":precision", ":scale", ":default", ":null", ":collation", ":comment", ":primary_key", ":if_exists", ":if_not_exists"]

    # PostgreSQL specific options
    default_keys.concat([":array", ":using", ":cast_as", ":as", ":type", ":enum_type", ":stored"])

    # CockroachDB specific options
    default_keys.concat([":srid", ":has_z", ":has_m", ":geographic", ":spatial_type", ":hidden"])

    "Unknown key: :#{key}. Valid keys are: #{default_keys.join(", ")}"
  end
end
prepend Ext
