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

# frozen-string-literal: true

require "active_support/duration"

module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      module OID
        module Interval # :nodoc:
          DEFAULT_PRECISION = 6 # microseconds

          def cast_value(value)
            case value
            when ::ActiveSupport::Duration
              value
            when ::String
              begin
                PostgresqlInterval::Parser.parse(value)
              rescue PostgresqlInterval::ParseError
                # Try ISO 8601
                super
              end
            else
              super
            end
          end

          def serialize(value)
            precision = self.precision || DEFAULT_PRECISION
            case value
            when ::ActiveSupport::Duration
              serialize_duration(value, precision)
            when ::Numeric
              serialize_duration(value.seconds, precision)
            else
              super
            end
          end

          def type_cast_for_schema(value)
            serialize(value).inspect
          end

          private

            # Convert an ActiveSupport::Duration to
            # the postgres interval style
            # ex. 1 year 2 mons 3 days 4 hours 5 minutes 6 seconds
            def serialize_duration(value, precision)
              yrs = value.parts.fetch(:years, 0)
              mons = value.parts.fetch(:months, 0)
              days = value.parts.fetch(:days, 0)
              hrs = value.parts.fetch(:hours, 0)
              mins = value.parts.fetch(:minutes, 0)
              secs = value.parts.fetch(:seconds, 0).round(precision)

              "#{yrs} years #{mons} mons #{days} days #{hrs} hours #{mins} minutes #{secs} seconds"
            end
        end

        PostgreSQL::OID::Interval.prepend(Interval)
      end

      module PostgresqlInterval
        class Parser
          PARTS = ActiveSupport::Duration::PARTS
          PARTS_IN_SECONDS = ActiveSupport::Duration::PARTS_IN_SECONDS

          # modified regex from https://github.com/jeremyevans/sequel/blob/master/lib/sequel/extensions/pg_interval.rb#L86
          REGEX = /\A([+-]?\d+ years?\s?)?([+-]?\d+ mons?\s?)?([+-]?\d+ days?\s?)?(?:([+-])?(\d{2,10}):(\d\d):(\d\d(\.\d+)?))?\z/

          def self.parse(string)
            matches = REGEX.match(string)
            raise(ParseError) unless matches

            # 1 => years, 2 => months, 3 => days, 4 => nil, 5 => hours,
            # 6 => minutes, 7 => seconds with fraction digits, 8 => fractional portion of 7
            duration = 0
            parts = {}

            if matches[1]
              val = matches[1].to_i
              duration += val * PARTS_IN_SECONDS[:years]
              parts[:years] = val
            end

            if matches[2]
              val = matches[2].to_i
              duration += val * PARTS_IN_SECONDS[:months]
              parts[:months] = val
            end

            if matches[3]
              val = matches[3].to_i
              duration += val * PARTS_IN_SECONDS[:days]
              parts[:days] = val
            end

            if matches[5]
              val = matches[5].to_i
              duration += val * PARTS_IN_SECONDS[:hours]
              parts[:hours] = val
            end

            if matches[6]
              val = matches[6].to_i
              duration += val * PARTS_IN_SECONDS[:minutes]
              parts[:minutes] = val
            end

            if matches[7]
              val = matches[7].to_f
              duration += val * PARTS_IN_SECONDS[:seconds]
              parts[:seconds] = val
            end

            ActiveSupport::Duration.new(duration, parts)
          end
        end

        class ParseError < StandardError
        end
      end
    end
  end
end
