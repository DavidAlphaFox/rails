# frozen_string_literal: true

module Rails
  class Engine < Railtie
    class Railties
      include Enumerable
      attr_reader :_all

      def initialize ## rails 通过这里加载每一个engine
        @_all ||= ::Rails::Railtie.subclasses.map(&:instance) +
          ::Rails::Engine.subclasses.map(&:instance)
      end

      def each(*args, &block)
        _all.each(*args, &block)
      end

      def -(others)
        _all - others
      end
    end
  end
end
