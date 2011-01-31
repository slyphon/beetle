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
      key = key.to_s

      if doc = collection.find_one({ :_id => msg_id, key => { :$exists => true } }, { :fields => { key => 1, :_id => 0 } })
        return doc[key].to_s
      end
    end

    def incr(msg_id, key)
      key = key.to_s

      opts = { 
        :query  => { :_id => msg_id },
        :update => { :$inc => { key => 1 } },
        :new => true,
        :fields => { key => 1 },
      }

      collection.find_and_modify(opts).fetch(key)
    end

    def msetnx(msg_id, values)
      query = { :_id => msg_id }
      values.keys.each { |k| query[k] = { :$exists => false } }
      
      result = collection.update(query, values, {:safe => true})
      result['updatedExisting'] ? 1 : 0
    end

    def setnx(msg_id, key, value)
      collection.update({:_id => msg_id, key => { :$exists => false }}, { key => value }, {:safe => true}).fetch('updatedExisting')
    end

    def del(msg_id, key)
      collection.update({:_id => msg_id, key => { :$exists => true }}, { :$unset => { key => 1 } }, {:safe => true}).fetch('updatedExisting')
    end

    def connection #:nodoc:
      @connection ||= Mongo::Connection.from_uri(@config.mongo_uri)
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
  end
end

