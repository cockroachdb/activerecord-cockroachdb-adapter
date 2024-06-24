# frozen_string_literal: true

# Copyright 2024 The Cockroach Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      module ColumnMethods
        def spatial(name, options = {})
          raise "You must set a type. For example: 't.spatial type: :st_point'" unless options[:type]

          column(name, options[:type], **options)
        end

        def geography(name, options = {})
          column(name, :geography, **options)
        end

        def geometry(name, options = {})
          column(name, :geometry, **options)
        end

        def geometry_collection(name, options = {})
          column(name, :geometry_collection, **options)
        end

        def line_string(name, options = {})
          column(name, :line_string, **options)
        end

        def multi_line_string(name, options = {})
          column(name, :multi_line_string, **options)
        end

        def multi_point(name, options = {})
          column(name, :multi_point, **options)
        end

        def multi_polygon(name, options = {})
          column(name, :multi_polygon, **options)
        end

        def st_point(name, options = {})
          column(name, :st_point, **options)
        end

        def st_polygon(name, options = {})
          column(name, :st_polygon, **options)
        end

        private

        def valid_column_definition_options
          spatial = [:srid, :has_z, :has_m, :geographic, :spatial_type]
          crdb = [:hidden]
          super + spatial + crdb
        end
      end
    end

    PostgreSQL::Table.include CockroachDB::ColumnMethods
  end
end
