module Beetle
  class MongoMessage < Message
    def set_timeout!
      logger.warn "Beetle: setting timeout"
      @store.update({ :_id => msg_id }, { :timeout => ( Time.now + timeout ) }, { :safe => true })
    end

    def timed_out?
      @store.find({ :_id => msg_id, :timeout => { :$lt => Time.now } }).count > 0 
    end

    def timed_out!
      @store.update({ :_id => msg_id }, { :timeout => 0 }, { :safe => true })
    end

    def completed?
      @store.find({ :_id => msg_id, :status => { :$eq => "completed" }} ).count > 0
    end

    def completed!
      @store.update({ :_id => msg_id }, { :status => 'completed' }, { :safe => true })
    end

    def delayed?
      @store.find({ :_id => msg_id, :delay => { :$gt => Time.now } }).count > 0
    end

    def set_delay!
      @store.update({ :_id => msg_id }, { :delay => (Time.now + delay) }, { :safe => true })
    end

    def attempts
      @store.find_one({ :_id => msg_id }, { :fields => { :_id => 0, :attempts => 1 } })['attempts'].to_i
    end

    def increment_execution_attempts!
      @store.update({ :_id => msg_id }, { :$inc => { :attempts => 1 }}, { :safe => true })
    end

    def attempts_limit_reached?
      @store.find({ :_id => msg_id, :attempts => { :$gte => attempts_limit } }).count > 0
    end

    def increment_exception_count!
      @store.update({ :_id => msg_id }, { :$inc => { :exceptions => 1 }}, { :safe => true })
    end

    def exceptions_limit_reached?
      @store.find({ :_id => msg_id, :exceptions => { :$gt => exceptions_limit } }).count > 0
    end

    require 'pp'

    #---
    # btw, having a query? method update the database as a *side effect*?
    # pretty weak.
    def key_exists?
      query = { :_id => msg_id }

      # we're only going to update the record if these keys don't exist
      %w[status expires timeout].each { |k| query[k] = { :$exists => false } }

      logger.debug "#{@store.find(query).to_a}"

      did_update = @store.update(query, { :status => 'incomplete', :expires => @expires_at, :timeout => (Time.now + timeout) }, { :safe => true }).fetch('updatedExisting')

      logger.debug "did_update of record? #{did_update.inspect}"
      
      logger.debug "Beetle: received duplicate message: #{msg_id} on queue #{@queue}" unless did_update

      # if we *didn't* update a record, that means that the key *did* already exist
      !did_update
    end

    def acquire_mutex!
      query = { :_id => msg_id, :mutex => { :$exists => false } }

      @store.update(query, { :mutex => Time.now }, { :safe => true }).fetch('updatedExisting').tap do |bool|
        if bool
          logger.debug "Beetle: acquired mutex: #{msg_id}"
        else
          delete_mutex!
        end
      end
    end

    def delete_mutex!
      if @store.update({ :_id => msg_id, :mutex => { :$exists => true } }, { :$unset => { :mutex => 1 } }, { :safe => true }).fetch('updatedExisting')
        logger.debug "Beetle: deleted mutex: #{msg_id}"
      end
    end

    protected
      def incr_ack_count
        @store.find_and_modify(:query => { :_id => msg_id }, :update => { :$inc => { :ack_count => 1 } }, :new => true).fetch('ack_count')
      end

      def ack!
        if !redundant? || (incr_ack_count >= 2)
          logger.debug "deleting record for msg_id: #{msg_id}"
          @store.remove({:_id => msg_id}, {:safe => true})
        end
      end
  end
end

