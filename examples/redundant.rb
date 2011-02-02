# redundant.rb
# 
# 
# 
# 
# ! check the examples/README.rdoc for information on starting your redis/rabbit !
#
# start it with ruby redundant.rb

require "rubygems"
require File.expand_path("../lib/beetle", File.dirname(__FILE__))

# set Beetle log level to info, less noisy than debug
Beetle.config.logger.level = Logger::DEBUG

logger = Beetle.config.logger

def create_mongo_logger
  Logger.new($stderr).tap do |log|
    log.level = Logger::WARN
    log.formatter = Logger::Formatter.new
  end
end

def mongo_repl_set
  Beetle.config.deduplication_store_impl = :mongodb

  Beetle.config.mongo_connection_proc = lambda do
    seeds = (0..2).to_a.map { |n| ['localhost', 37000 + n] }
    seeds << { :rs_name => 'rset0', :logger => create_mongo_logger, :safe => true }
    Mongo::ReplSetConnection.new(*seeds)
  end
end

def mongo_solo
  Beetle.config.deduplication_store_impl = :mongodb

  Beetle.config.mongo_connection_proc = lambda do
    log = Logger.new($stderr).tap do |log|
      log.level = Logger::DEBUG
      log.formatter = Logger::Formatter.new
    end

    Mongo::Connection.new('localhost', 27017, :safe => true, :logger => create_mongo_logger)
  end
end

mongo_solo
# mongo_repl_set
# Beetle.config.deduplication_store_impl = :redis



# use two servers
Beetle.config.servers = "localhost:5672, localhost:5673"
# instantiate a client
client = Beetle::Client.new

# register a durable queue named 'test'
# this implicitly registers a durable topic exchange called 'test'
client.register_queue(:test)
client.purge(:test)
client.register_message(:test, :redundant => true)

# register a handler for the test message, listing on queue "test"
k = 0
client.register_handler(:test) do |m|
  k += 1
  puts "Received test message from server #{m.server}"
  puts m.msg_id
  p m.header
  puts "Message content: #{m.data}"
  puts
end


# publish some test messages
# at this point, the exchange will be created on the server and the queue will be bound to the exchange
N = 3
n = 0
N.times do |i|
  n += client.publish(:test, "Hello#{i+1}")
end
puts "published #{n} test messages"
puts

expected_publish_count = 2*N
if n != expected_publish_count
  puts "could not publish all messages"
  exit 1
end

start_time = Time.now

# start listening
# this starts the event machine event loop using EM.run
# the block passed to listen will be yielded as the last step of the setup process
client.listen do
  EM.add_timer(0.1) do 
    if (k >= N) or ((Time.now - start_time).to_i > 10)
      client.stop_listening
    end
  end
end

puts "Received #{k} test messages"
raise "Your setup is borked" if N != k
