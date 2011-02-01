module Beetle
  # Handles establishing a connection to mongo according to the configs, and wraps calls to the
  # collection object in a retry block. In case of a connection failure, calls
  # will automatically be retried, so it's important to make sure modifications are atomic.
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

    def method_missing(sym, *args, &block)
      if collection.respond_to?(sym)
        handle_failover do
          collection.__send__(sym, *args, &block)
        end
      else
        super
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

