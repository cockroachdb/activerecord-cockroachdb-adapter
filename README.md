# ActiveRecord CockroachDB Adapter

CockroachDB adapter for ActiveRecord 5. This is a lightweight extension of the PostgreSQL adapter that establishes compatibility with [CockroachDB](https://github.com/cockroachdb/cockroach).

## Installation

Add this line to your project's Gemfile:

```ruby
gem 'activerecord-cockroachdb-adapter', '~> 0.2.1'
```

In `database.yml`, use the following adapter setting:

```
development:
  adapter: cockroachdb
  port: 26257
```
