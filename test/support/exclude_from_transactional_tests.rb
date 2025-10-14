# frozen_string_literal: true

# Allow exclusion of tests by name using #exclude_from_transactional_tests(test_name)
module ExcludeFromTransactionalTests
  module ClassMethods
    def exclude_from_transactional_tests(name)
      @non_transactional_list ||= []
      @non_transactional_list << name.to_s
    end

    def non_transactional_list
      @non_transactional_list ||= []
    end
  end

  def self.prepended(base)
    base.extend ClassMethods
  end

  def before_setup
    @old_use_transactional_tests = self.use_transactional_tests
    if @old_use_transactional_tests # stay false if false
      self.use_transactional_tests = !self.class.non_transactional_list.include?(@NAME.to_s)
    end
    super
  end

  def after_teardown
    super
  ensure
    self.use_transactional_tests = @old_use_transactional_tests
  end
end
