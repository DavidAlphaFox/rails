# frozen_string_literal: true

module ActiveSupport
  # A typical module looks like this:
  #
  #   module M
  #     def self.included(base)
  #       base.extend ClassMethods
  #       base.class_eval do
  #         scope :disabled, -> { where(disabled: true) }
  #       end
  #     end
  #
  #     module ClassMethods
  #       ...
  #     end
  #   end
  #
  # By using <tt>ActiveSupport::Concern</tt> the above module could instead be
  # written as:
  #
  #   require 'active_support/concern'
  #
  #   module M
  #     extend ActiveSupport::Concern
  #
  #     included do
  #       scope :disabled, -> { where(disabled: true) }
  #     end
  #
  #     class_methods do
  #       ...
  #     end
  #   end
  #
  # Moreover, it gracefully handles module dependencies. Given a +Foo+ module
  # and a +Bar+ module which depends on the former, we would typically write the
  # following:
  #
  #   module Foo
  #     def self.included(base)
  #       base.class_eval do
  #         def self.method_injected_by_foo
  #           ...
  #         end
  #       end
  #     end
  #   end
  #
  #   module Bar
  #     def self.included(base)
  #       base.method_injected_by_foo
  #     end
  #   end
  #
  #   class Host
  #     include Foo # We need to include this dependency for Bar
  #     include Bar # Bar is the module that Host really needs
  #   end
  #
  # But why should +Host+ care about +Bar+'s dependencies, namely +Foo+? We
  # could try to hide these from +Host+ directly including +Foo+ in +Bar+:
  #
  #   module Bar
  #     include Foo
  #     def self.included(base)
  #       base.method_injected_by_foo
  #     end
  #   end
  #
  #   class Host
  #     include Bar
  #   end
  #
  # Unfortunately this won't work, since when +Foo+ is included, its <tt>base</tt>
  # is the +Bar+ module, not the +Host+ class. With <tt>ActiveSupport::Concern</tt>,
  # module dependencies are properly resolved:
  #
  #   require 'active_support/concern'
  #
  #   module Foo
  #     extend ActiveSupport::Concern
  #     included do
  #       def self.method_injected_by_foo
  #         ...
  #       end
  #     end
  #   end
  #
  #   module Bar
  #     extend ActiveSupport::Concern
  #     include Foo
  #
  #     included do
  #       self.method_injected_by_foo
  #     end
  #   end
  #
  #   class Host
  #     include Bar # It works, now Bar takes care of its dependencies
  #   end
  module Concern
    class MultipleIncludedBlocks < StandardError #:nodoc:
      def initialize
        super "Cannot define multiple 'included' blocks for a Concern"
      end
    end

    def self.extended(base) #:nodoc:
      # Add a new instance variable with default value
      ## 当自己被扩展的时候，给扩展自己的类添加一个全局变量
      base.instance_variable_set(:@_dependencies, [])
    end
    # execute after inclued
    ## Ruby的机制，在included之后会调用self.included和append_features
    def append_features(base)
      # if we find that there is a @_dependencies variable
      # it must extend Concern
      # We put ourselves into @_dependencies
      if base.instance_variable_defined?(:@_dependencies)
        base.instance_variable_get(:@_dependencies) << self
        return false
      else
        return false if base < self
        # modules which all extend Concern
        @_dependencies.each { |dep| base.include(dep) }
        super
        ## if base Class defined ClassMethods Module
        ## We will extend it
        ## 无论我们是否定义class_methods方法
        ## concern发现我们定义了ClassMethod的module，都会让base扩展ClassMethods模块
        base.extend const_get(:ClassMethods) if const_defined?(:ClassMethods)
        ## 如果我们有included_block了，会在base内直接执行这些block
        base.class_eval(&@_included_block) if instance_variable_defined?(:@_included_block)
      end
    end
    # method_name [( [arg [= default]]...[, * arg [, &expr ]])]
    # This really likes Lisp
    def included(base = nil, &block)
      if base.nil?
        raise MultipleIncludedBlocks if instance_variable_defined?(:@_included_block)

        @_included_block = block
      else
        super
      end
    end

    def class_methods(&class_methods_module_definition)
      # Find ClassMethods module
      # 如果定义了ClassMethods这个module就使用已经定义的
      mod = const_defined?(:ClassMethods, false) ?
        const_get(:ClassMethods) :
        const_set(:ClassMethods, Module.new)
      # define a ClassMethods Module and put methods into it
      mod.module_eval(&class_methods_module_definition)
    end
  end
end
