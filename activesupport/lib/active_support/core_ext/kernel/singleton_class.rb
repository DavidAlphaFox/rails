# frozen_string_literal: true

module Kernel
  # class_eval on an object acts like singleton_class.class_eval.
  ## overwrite Kernel.class_eval ?
  ## what's different between Kernel.class_eval and singleton_class.class_eval?
  def class_eval(*args, &block)
    singleton_class.class_eval(*args, &block)
  end
end
