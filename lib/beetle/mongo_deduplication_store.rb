module Beetle
  #--
  # MongoDB has N-way replication w/ automatic failover (replica-sets), so we
  # don't need the config reloading stuff in here.
  class MongoDeduplicationStore
    include Logging

    def initialize(config = Beetle.config)
      @config = config
    end

    def prepare(msg_id)
      doc = {
        :_id        => msg_id, 
#         :timeout    => 0,
#         :status     => nil,
#         :delay      => nil,
#         :attempts   => 0,
#         :exceptions => 0,
#         :expires    => nil,
      }

      collection.insert(doc, :safe => true)
      true
    rescue Mongo::OperationFailure => e
      raise e unless e.message =~ /^11000/  # duplicate key error, OK, document already exists for message
    end

    def set(msg_id, key, value)
      collection.update({:_id => msg_id, key => value}, {:safe => true})
    end

    def get(msg_id, key)
      collection.find_one({:id => msg_id}, {:fields => key})
    end

    def incr(msg_id, key)
      collection.update({:_id => msg_id}, {:$inc => { key => 1 }}, {:safe => true})
    end

    def msetnx(msg_id, values)
      query = { :_id => msg_id }
      values.keys.each { |k| query[k] = { :$exists => false } }
      
      result = collection.update(query, values, {:safe => true})
      result['updatedExisting'] ? 1 : 0
    end

    def setnx(msg_id, key, value)
      result = collection.update({:_id => msg_id, key => { :$exists => false }}, {key => value}, {:safe => true})
      result['updatedExisting'] ? 1 : 0
    end

    def del(msg_id, key)
      collection.update({:_id => msg_id}, {:$unset => { key => 1 } }, {:safe => true})
    end

    protected
      def connection
        @connection ||= Mongo::Connection.from_uri(@config.mongo_uri)
      end

      def db
        @db ||= connection[@config.mongo_db_name]
      end

      def collection
        @collection ||= db[@config.mongo_collection_name]
      end
  end
end

