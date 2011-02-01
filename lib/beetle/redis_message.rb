module Beetle
  class RedisMessage < Message
    def set_timeout!
      $stderr.puts "setting timeout"
      @store.set(msg_id, :timeout, now + timeout)
    end

    def timed_out?
      ts_now = now
      t = @store.get(msg_id, :timeout).to_i
      logger.warn "timed_out? ts_now: #{ts_now}, recoreded time: #{t}"
      t.to_i < ts_now
    end

    def timed_out!
      @store.set(msg_id, :timeout, 0)
    end

    def completed?
      @store.get(msg_id, :status) == "completed"
    end

    def completed!
      @store.set(msg_id, :status, "completed")
      timed_out!
    end

    def delayed?
      (t = @store.get(msg_id, :delay)) && t.to_i > now
    end

    def set_delay!
      @store.set(msg_id, :delay, now + delay)
    end

    def attempts
      @store.get(msg_id, :attempts).to_i
    end

    def increment_execution_attempts!
      @store.incr(msg_id, :attempts)
    end

    def attempts_limit_reached?
      (limit = @store.get(msg_id, :attempts)) && limit.to_i >= attempts_limit
    end

    def increment_exception_count!
      @store.incr(msg_id, :exceptions)
    end

    def exceptions_limit_reached?
      @store.get(msg_id, :exceptions).to_i > exceptions_limit
    end

    def key_exists?
      old_message = 0 == @store.msetnx(msg_id, :status =>"incomplete", :expires => @expires_at, :timeout => now + timeout)
      if old_message
        logger.debug "Beetle: received duplicate message: #{msg_id} on queue: #{@queue}"
      end
      old_message
    end

    def aquire_mutex!
      if mutex = @store.setnx(msg_id, :mutex, now)
        logger.debug "Beetle: aquired mutex: #{msg_id}"
      else
        delete_mutex!
      end
      mutex
    end

    def delete_mutex!
      @store.del(msg_id, :mutex)
      logger.debug "Beetle: deleted mutex: #{msg_id}"
    end
  end
end

