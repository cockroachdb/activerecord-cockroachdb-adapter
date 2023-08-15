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
