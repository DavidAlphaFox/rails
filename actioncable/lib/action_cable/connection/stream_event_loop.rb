# frozen_string_literal: true

# :markup: markdown

require "nio"

module ActionCable
  module Connection
    class StreamEventLoop
      def initialize
        @nio = @executor = @thread = nil
        @map = {}
        @stopping = false
        @todo = Queue.new

        @spawn_mutex = Mutex.new
      end #创建新的EventLoop

      def timer(interval, &block)
        Concurrent::TimerTask.new(execution_interval: interval, &block).tap(&:execute)
      end

      def post(task = nil, &block)
        task ||= block

        spawn
        @executor << task
      end

      def attach(io, stream)
        @todo << lambda do
          @map[io] = @nio.register(io, :r)
          @map[io].value = stream
        end
        wakeup
      end

      def detach(io, stream)
        @todo << lambda do
          @nio.deregister io
          @map.delete io
          io.close
        end
        wakeup
      end

      def writes_pending(io)
        @todo << lambda do
          if monitor = @map[io]
            monitor.interests = :rw
          end
        end
        wakeup
      end

      def stop
        @stopping = true
        wakeup if @nio
      end

      private
        def spawn
          return if @thread && @thread.status ##如果已经存在线程就立刻返回

          @spawn_mutex.synchronize do
            return if @thread && @thread.status ##二次检查

            @nio ||= NIO::Selector.new ## 创建新的NIO

            @executor ||= Concurrent::ThreadPoolExecutor.new(
              min_threads: 1,
              max_threads: 10,
              max_queue: 0,
            ) ## 创建新的执行器

            @thread = Thread.new { run } ## 使用线程执行run函数

            return true
          end
        end

        def wakeup
          spawn || @nio.wakeup ##唤醒NIO
        end

        def run
          loop do
            if @stopping ## 如果得到stop信号，立刻关闭NIO，结束执行
              @nio.close
              break
            end

            until @todo.empty? ## 循环执行@todo队列直到当前对立中任务执行完成
              @todo.pop(true).call
            end

            next unless monitors = @nio.select ## 从NIO中选择所有关注的时间

            monitors.each do |monitor|
              io = monitor.io
              stream = monitor.value

              begin
                if monitor.writable?
                  if stream.flush_write_buffer
                    monitor.interests = :r
                  end
                  next unless monitor.readable?
                end

                incoming = io.read_nonblock(4096, exception: false)
                case incoming
                when :wait_readable
                  next
                when nil
                  stream.close
                else
                  stream.receive incoming
                end
              rescue
                # We expect one of EOFError or Errno::ECONNRESET in normal operation (when the
                # client goes away). But if anything else goes wrong, this is still the best way
                # to handle it.
                begin
                  stream.close
                rescue
                  @nio.deregister io
                  @map.delete io
                end
              end
            end
          end
        end
    end
  end
end
