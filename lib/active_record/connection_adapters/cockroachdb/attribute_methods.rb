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
  module CockroachDB
    module AttributeMethodsMonkeyPatch

      private

      # Filter out rowid so it doesn't get inserted by ActiveRecord. rowid is a
      # column added by CockroachDB for tables that don't define primary keys.
      # CockroachDB will automatically insert rowid values. See
      # https://www.cockroachlabs.com/docs/v19.2/create-table.html#create-a-table.
      def attributes_for_create(attribute_names)
        super.reject { |name| name == ConnectionAdapters::CockroachDBAdapter::DEFAULT_PRIMARY_KEY }
      end

      # Filter out rowid so it doesn't get updated by ActiveRecord. rowid is a
      # column added by CockroachDB for tables that don't define primary keys.
      # CockroachDB will automatically insert rowid values. See
      # https://www.cockroachlabs.com/docs/v19.2/create-table.html#create-a-table.
      def attributes_for_update(attribute_names)
        super.reject { |name| name == ConnectionAdapters::CockroachDBAdapter::DEFAULT_PRIMARY_KEY }
      end
    end
  end

  class Base
    prepend CockroachDB::AttributeMethodsMonkeyPatch
  end
end
