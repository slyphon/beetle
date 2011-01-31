#!/usr/bin/env ruby

require 'beetle'
require 'logger'

REPLSET_NAME = 'rset0'

def main
  log = Logger.new($stderr).tap do |log|
    log.level = Logger::DEBUG
    log.formatter = Logger::Formatter.new
  end

  seeds = ['localhost', 37000]

  Beetle.config do |config|
    config.mongo_connection_proc = lambda do
      seeds = (0..2).to_a.map { |n| ['localhost', 37000 + n] }
      
      args = [*seeds, {:rs_name => REPLSET_NAME, :logger => log}]

      Mongo::ReplSetConnection.new(*args)
    end
  end


  mds = Beetle::MongoDeduplicationStore.new

  $stderr.puts "starting loop"

  while true
    msg_id = Beetle::UUID.uuid
    mds.prepare(msg_id)
    mds.set(msg_id, 'foo', 0)
    mds.get(msg_id, 'foo')
    mds.del(msg_id, 'foo')
    sleep(0.7)
  end
rescue Interrupt
  exit 0
end

main

