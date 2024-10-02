# frozen_string_literal: true

require "support/copy_cat"

raise "a new setup has been added" if get_callbacks(:setup).count > 1

reset_callbacks :setup

setup do
  @connection = ActiveRecord::Base.lease_connection
  @connection.create_table("postgresql_network_addresses", force: true) do |t|
    t.inet "inet_address", default: "192.168.1.1"
    # Unsupported types cidr and macaddr
    # t.cidr "cidr_address", default: "192.168.1.0/24"
    # t.macaddr "mac_address", default: "ff:ff:ff:ff:ff:ff"
  end
end

exclude :test_cidr_column, "CockroachDB does not currently support the 'cidr' type."
exclude :test_cidr_change_prefix, "CockroachDB does not currently support the 'cidr' type."
exclude :test_macaddr_column, "CockroachDB does not currently support the 'macaddr' type."
exclude :test_mac_address_change_case_does_not_mark_dirty, "CockroachDB does not currently support the 'macaddr' type."

CopyCat.copy_methods(self, self, :test_schema_dump_with_shorthand) do
  def on_send(node)
    return unless node in [:send, nil, :assert_match,
      [:regexp, [:str, /(cidr|mac)_address/], *],
      *
    ]
    remove(node.location.expression)
  end
end

CopyCat.copy_methods(self, self, :test_network_types, :test_invalid_network_address) do
  def on_send(node)
    case node
    in [:send, [:const, nil, :PostgresqlNetworkAddress], /create|new/, [:hash, *pairs]]

      pairs.each do |pair|
        if pair in [:pair, [:sym, /(cidr|mac)_address/], *]
          expr = pair.location.expression
          large_expr = expr.resize(expr.size + 1)
          expr = large_expr if large_expr.source.end_with?(",")
          remove(expr)
        end
      end
    in [:send, [:lvar, :address], /(cidr|mac)_address/, *]
      remove(node.location.expression)
    in [:send, nil, /assert_(equal|nil)/, *list]
      # Recursive search for cidr or mac in test assertions.
      until list.empty?
        el = list.shift
        if el.respond_to?(:children)
          list.concat(el.children)
        else
          if el.respond_to?(:to_s)
            str = el.to_s.downcase
            if str.include?("cidr") || str.include?("mac")
              remove(node.location.expression)
              break
            end
          end
        end
      end
    else
      # Nothing
    end
  end
end
