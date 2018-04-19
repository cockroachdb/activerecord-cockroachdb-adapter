# ActiveRecord CockroachDB Adapter

CockroachDB adapter for ActiveRecord 4 and 5. This is a lightweight extension of the PostgreSQL adapter that establishes compatibility with [CockroachDB](https://github.com/cockroachdb/cockroach).

## Installation

Add this line to your project's Gemfile:

```ruby
gem 'activerecord-cockroachdb-adapter', '~> 0.2.2'
```

If you're using Rails 4.x, use the `0.1.x` versions of this gem.

In `database.yml`, use the following adapter setting:

```
development:
  adapter: cockroachdb
  port: 26257
  host: <hostname>
  user: <username>
```


## Modifying the adapter?

See [CONTRIBUTING.md](/CONTRIBUTING.md) for more details on setting up
the environment and making modifications.