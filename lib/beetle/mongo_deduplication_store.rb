module Beetle
  #--
  # MongoDB has N-way replication w/ automatic failover (replica-sets), so we
  # don't need the config reloading stuff in here.
  class MongoDeduplicationStore
    include Logging

    SET_OPER_RVAL = 'OK'
    MAX_RETRY_DELAY = 5 # seconds

    def initialize(config = Beetle.config)
      @config = config
    end

    def prepare(msg_id)
      doc = { :_id => msg_id }

      handle_failover do
        collection.insert(doc, :safe => true)
      end

      nil
    rescue Mongo::OperationFailure => e
      raise e unless e.message =~ /^11000/  # duplicate key error, OK, document already exists for message
    end

    def set(msg_id, key, value)
      handle_failover do
        collection.update({:_id => msg_id, key => value}, {:safe => true})
      end
      SET_OPER_RVAL
    end

    def get(msg_id, key)
      key = key.to_s

      handle_failover do
        if doc = collection.find_one({ :_id => msg_id, key => { :$exists => true } }, { :fields => { key => 1, :_id => 0 } })
          return doc[key].to_s
        end
      end
    end

    def incr(msg_id, key)
      key = key.to_s

      opts = { 
        :query  => { :_id => msg_id },
        :update => { :$inc => { key => 1 } },
        :new => true,
        :fields => { key => 1, :_id => 0 },
      }

      handle_failover do
        collection.find_and_modify(opts).fetch(key)
      end
    end

    def msetnx(msg_id, values)
      query = { :_id => msg_id }
      values.keys.each { |k| query[k] = { :$exists => false } }
      
      handle_failover do
        collection.update(query, values, {:safe => true})['updatedExisting'] ? 1 : 0
      end
    end

    def setnx(msg_id, key, value)
      handle_failover do
        collection.update({:_id => msg_id, key => { :$exists => false }}, { key => value }, {:safe => true}).fetch('updatedExisting')
      end
    end

    def del(msg_id, key)
      handle_failover do
        collection.update({:_id => msg_id, key => { :$exists => true }}, { :$unset => { key => 1 } }, {:safe => true}).fetch('updatedExisting')
      end
    end

    def connection #:nodoc:
      @connection ||= 
        if @config.mongo_connection_proc
          @config.mongo_connection_proc.call
        else
          Mongo::Connection.from_uri(@config.mongo_uri)
        end
    end

    def db #:nodoc:
      @db ||= connection[@config.mongo_db_name]
    end

    def collection #:nodoc:
      @collection ||= db[@config.mongo_collection_name]
    end

    # only for testing!
    def drop_collection_only_for_tests_danger_will_robinson_danger! #:nodoc:
      db.drop_collection(@config.mongo_collection_name)
    end

    # catches Mongo::ConnectionFailure and retries operation after a random delay (avoid the thundering herd!)
    def handle_failover #:nodoc:
      yield
    rescue Mongo::ConnectionFailure
      delay = rand() * MAX_RETRY_DELAY
      $stderr.puts("Caught Mongo::ConnectionFailure, retrying after %0.2f second delay" % [delay])
      sleep(delay)
      retry
    end
  end
end

