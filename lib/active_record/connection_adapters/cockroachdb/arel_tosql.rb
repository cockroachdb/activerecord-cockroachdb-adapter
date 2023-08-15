# frozen_string_literal: true

module RGeo
  module ActiveRecord
    ##
    # Extend rgeo-activerecord visitors to use PostGIS specific functionality
    module SpatialToPostGISSql
      def visit_in_spatial_context(node, collector)
        # Use ST_GeomFromEWKT for EWKT geometries
        if node.is_a?(String) && node =~ /SRID=[\d+]{0,};/
          collector << "#{st_func('ST_GeomFromEWKT')}(#{quote(node)})"
        else
          super(node, collector)
        end
      end
    end
  end
end
RGeo::ActiveRecord::SpatialToSql.prepend RGeo::ActiveRecord::SpatialToPostGISSql

module Arel # :nodoc:
  module Visitors # :nodoc:
    class CockroachDB < PostgreSQL  # :nodoc:
      include RGeo::ActiveRecord::SpatialToSql

      def visit_Arel_Nodes_JoinSource(o, collector)
        super
        if o.aost
          collector << " AS OF SYSTEM TIME '#{o.aost.iso8601}'"
        end
        collector
      end
    end
  end
end
