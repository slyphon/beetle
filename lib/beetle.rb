$:.unshift(File.expand_path('..', __FILE__))
require 'bunny-ext'

require 'active_support/all'
require 'redis'

require 'mongo'

unless defined?(::JRUBY_VERSION)
  require 'uuid4r'
end


if defined?(::JRUBY_VERSION)
  require 'java'
end

require 'set'

module Beetle

  # abstract superclass for Beetle specific exceptions
  class Error < StandardError; end
  # raised when Beetle detects configuration errors
  class ConfigurationError < Error; end
  # raised when trying to access an unknown message
  class UnknownMessage < Error; end
  # raised when trying to access an unknown queue
  class UnknownQueue < Error; end
  # raised when no redis master server can be found
  class NoRedisMaster < Error; end
  # raise when no message could be sent by the publisher
  class NoMessageSent < Error; end

  # AMQP options for exchange creation
  EXCHANGE_CREATION_KEYS  = [:auto_delete, :durable, :internal, :nowait, :passive]
  # AMQP options for queue creation
  QUEUE_CREATION_KEYS     = [:passive, :durable, :exclusive, :auto_delete, :no_wait]
  # AMQP options for queue bindings
  QUEUE_BINDING_KEYS      = [:key, :no_wait]
  # AMQP options for message publishing
  PUBLISHING_KEYS         = [:key, :mandatory, :immediate, :persistent, :reply_to]
  # AMQP options for subscribing to queues
  SUBSCRIPTION_KEYS       = [:ack, :key]

  # use ruby's autoload mechanism for loading beetle classes
  lib_dir = File.expand_path(File.dirname(__FILE__) + '/beetle/')
  Dir["#{lib_dir}/*.rb"].each do |libfile|
    autoload File.basename(libfile)[/^(.*)\.rb$/, 1].classify, libfile
  end

  # XXX(slyphon) couldn't get the autoload to work properly for this...
  require "#{lib_dir}/uuid"

  require "#{lib_dir}/redis_ext"

  # returns the default configuration object and yields it if a block is given
  def self.config
    #:yields: config
    @config ||= Configuration.new
    block_given? ? yield(@config) : @config
  end

  # FIXME: there should be a better way to test
  if defined?(Mocha)
    def self.reraise_expectation_errors! #:nodoc:
      raise if $!.is_a?(Mocha::ExpectationError)
    end
  else
    def self.reraise_expectation_errors! #:nodoc:
    end
  end

  Timer = begin
    RUBY_VERSION < "1.9" ? SystemTimer : Timeout
  rescue NameError
    warn "WARNING: It's highly recommended to install the SystemTimer gem: `gem install SystemTimer -v '=1.2.1'` See: http://ph7spot.com/musings/system-timer" if RUBY_VERSION < "1.9"
    Timeout
  end
end

#----------------------------------------------
# MONKEY PATCH AMQP!
require 'amqp'
require 'mq'

if AMQP::VERSION == '0.7.0'
  MQ::Header.class_eval do
    # Reject this message (XXX currently unimplemented in rabbitmq)
    # * :requeue => true | false (default false)
    def reject(opts = {})
      # it's '@mq.connection.broker', not @mq.broker!!
#       if @mq.connection.broker.server_properties[:product] == "RabbitMQ"
#         raise NotImplementedError.new("RabbitMQ doesn't implement the Basic.Reject method\nSee http://lists.rabbitmq.com/pipermail/rabbitmq-discuss/2009-February/002853.html")
#       else
        @mq.callback {
          @mq.send AMQP::Protocol::Basic::Reject.new(opts.merge(:delivery_tag => properties[:delivery_tag]))
        }
#       end
    end
  end
end

#----------------------------------------------

