# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/book"
require "active_support/log_subscriber/test_helper"

module CockroachDB
  class EnumTest < ActiveRecord::TestCase
    fixtures :books, :authors, :author_addresses

    setup do
      @book = books(:awdr)
    end

    test "enum logs a warning if auto-generated negative scopes would clash with other enum names" do
      old_logger = ActiveRecord::Base.logger
      logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new

      ActiveRecord::Base.logger = logger

      expected_message_1 = "Enum element 'not_sent' in Book uses the prefix 'not_'."\
        " This has caused a conflict with auto generated negative scopes."\
        " Avoid using enum elements starting with 'not' where the positive form is also an element."

      Class.new(ActiveRecord::Base) do
        def self.name
          "Book"
        end
        enum status: [:sent, :not_sent]
      end

      assert_includes(logger.logged(:warn), expected_message_1)
    ensure
      ActiveRecord::Base.logger = old_logger
    end

    test "enum logs a warning if auto-generated negative scopes would clash with other enum names regardless of order" do
      old_logger = ActiveRecord::Base.logger
      logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new

      ActiveRecord::Base.logger = logger

      expected_message_1 = "Enum element 'not_sent' in Book uses the prefix 'not_'."\
        " This has caused a conflict with auto generated negative scopes."\
        " Avoid using enum elements starting with 'not' where the positive form is also an element."

      Class.new(ActiveRecord::Base) do
        def self.name
          "Book"
        end
        enum status: [:not_sent, :sent]
      end

      assert_includes(logger.logged(:warn), expected_message_1)
    ensure
      ActiveRecord::Base.logger = old_logger
    end

    test "enum doesn't log a warning if no clashes detected" do
      old_logger = ActiveRecord::Base.logger
      logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new

      ActiveRecord::Base.logger = logger

      Class.new(ActiveRecord::Base) do
        def self.name
          "Book"
        end
        enum status: [:not_sent]
      end

      assert_empty(logger.logged(:warn))
    ensure
      ActiveRecord::Base.logger = old_logger
    end

    test "enum doesn't log a warning if opting out of scopes" do
      old_logger = ActiveRecord::Base.logger
      logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new

      ActiveRecord::Base.logger = logger

      Class.new(ActiveRecord::Base) do
        def self.name
          "Book"
        end
        enum status: [:not_sent, :sent], _scopes: false
      end

      assert_empty(logger.logged(:warn))
    ensure
      ActiveRecord::Base.logger = old_logger
    end
  end
end
