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

module Arel
  module Nodes
    module JoinSourceExt
      def initialize(...)
        super
        @aost = nil
      end

      def hash
        [*super, aost].hash
      end

      def eql?(other)
        super && aost == other.aost
      end
      alias_method :==, :eql?
    end
    JoinSource.attr_accessor :aost
    JoinSource.prepend JoinSourceExt
  end
  module SelectManagerExt
    def aost(time)
      @ctx.source.aost = time
      nil
    end
  end
  SelectManager.prepend SelectManagerExt
end
