# frozen_string_literal: true

module ActiveRecord
  class Relation
    module QueryMethodsExt
      def aost!(time) # :nodoc:
        unless time.nil? || time.is_a?(Time)
          raise ArgumentError, "Unsupported argument type: #{time} (#{time.class})"
        end

        @aost = time
        self
      end

      # Set system time for the current query. Using
      # `.aost(nil)` resets.
      #
      # See cockroachlabs.com/docs/stable/as-of-system-time
      def aost(time)
        spawn.aost!(time)
      end

      def from!(...) # :nodoc:
        @force_index = nil
        @index_hint = nil
        super
      end

      # Set table index hint for the query to the
      # given `index_name`, and `direction` (either
      # `ASC` or `DESC`).
      #
      # Any call to `ActiveRecord::QueryMethods#from`
      # will reset the index hint. Index hints are
      # not set if the `from` clause is not a table
      # name.
      #
      # @see https://www.cockroachlabs.com/docs/v22.2/table-expressions#force-index-selection
      def force_index(index_name, direction: nil)
        spawn.force_index!(index_name, direction: direction)
      end

      def force_index!(index_name, direction: nil)
        return self unless from_clause_is_a_table_name?

        index_name = sanitize_sql(index_name.to_s)
        direction = direction.to_s.upcase
        direction = %w[ASC DESC].include?(direction) ? ",#{direction}" : ""

        @force_index = "FORCE_INDEX=#{index_name}#{direction}"
        self.from_clause = build_from_clause_with_hints
        self
      end

      # Set table index hint for the query with the
      # given `hint`. This allows more control over
      # the hint than `ActiveRecord::Relation#force_index`.
      # For instance, you could set it to `NO_FULL_SCAN`.
      #
      # Any call to `ActiveRecord::QueryMethods#from`
      # will reset the index hint. Index hints are
      # not set if the `from` clause is not a table
      # name.
      #
      # @see https://www.cockroachlabs.com/docs/v22.2/table-expressions#force-index-selection
      def index_hint(hint)
        spawn.index_hint!(hint)
      end

      def index_hint!(hint)
        return self unless from_clause_is_a_table_name?

        hint = sanitize_sql(hint.to_s)
        @index_hint = hint.to_s
        self.from_clause = build_from_clause_with_hints
        self
      end

      def show_create
        quoted_table = connection.quote_table_name self.table_name
        connection.select_one("show create table #{quoted_table}")["create_statement"]
      end

      private

      def build_arel(...)
        arel = super
        arel.aost(@aost) if @aost.present?
        arel
      end

      def from_clause_is_a_table_name?
        # if empty, we are just dealing with the current table.
        return true if from_clause.empty?
        # `from_clause` can be a subquery.
        return false unless from_clause.value.is_a?(String)
        # `from_clause` can be a list of tables or a function.
        # A simple way to check is to see if the string
        # contains special characters. But we have to
        # not check against an existing table hint.
        return !from_clause.value.gsub(/\@{.*?\}/, "").match?(/[,\(]/)
      end

      def build_from_clause_with_hints
        table_hints = [@index_hint, @force_index].compact.join(",")

        table_name =
          if from_clause.empty?
            quoted_table_name
          else
            # Remove previous table hints if any. And spaces.
            from_clause.value.partition("@").first.strip
          end
        Relation::FromClause.new("#{table_name}@{#{table_hints}}", nil)
      end
    end

    QueryMethods.prepend(QueryMethodsExt)
  end
  # `ActiveRecord::Base` ancestors do not include `QueryMethods`.
  # But the `#all` method returns a relation, which has `QueryMethods`
  # as ancestor. That is how active_record is doing is as well.
  #
  # @see https://github.com/rails/rails/blob/914130a9f/activerecord/lib/active_record/querying.rb#L23
  Querying.delegate(:force_index, :index_hint, :aost, :show_create, to: :all)
end
