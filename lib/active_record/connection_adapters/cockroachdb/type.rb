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
  module Type
    module CRDBExt
      # Return :postgresql instead of :cockroachdb for current_adapter_name so
      # we can continue using the ActiveRecord::Types defined in
      # PostgreSQLAdapter.
      def adapter_name_from(model)
        name = super
        return :postgresql if name == :cockroachdb

        name
      end
    end
    singleton_class.prepend CRDBExt
  end
end
