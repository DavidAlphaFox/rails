# frozen_string_literal: true

module Kernel
  # class_eval on an object acts like singleton_class.class_eval.
  ## overwrite Kernel.class_eval
  ## after doing this
  ## we can let obejct have the ability of class_eval
  def class_eval(*args, &block)
    singleton_class.class_eval(*args, &block)
  end
end
=begin
  after doing this
  we can have this

  class A
    def show
      puts "class A"
    end
  end
  a = A.new
  a.class_eval "def instance_show ; puts \"instance A\"; end;"

  And it same as below before overwrite Kernel module
  class A
    def show
      puts "class A"
    end
  end
  a = A.new
  class << a
    def instance_show
      puts "instance A"
    end
  end

Object is a Class and Class is a Object
Object is an instance Class but Class isn`t an instance Object

Because class_eval is defined in Module class
,class A is an instance Class and Class's superclass is Module
,so class A won't call class_eval in Kernel module

a is inherited from Object and Object mixin Kernel ,
when a call class_eval ,it will be class_eval in Kernel module
=end
