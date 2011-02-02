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

    protected
      # ack the message for rabbit. deletes all keys associated with this message in the
      # deduplication store if we are sure this is the last message with the given msg_id.
      def ack!
        #:doc:
        logger.debug "Beetle: ack! for message #{msg_id}"
        header.ack
        return if simple? # simple messages don't use the deduplication store
        if !redundant? || @store.incr(msg_id, :ack_count) == 2
          @store.del_keys(msg_id)
        end
      end
  end
end

