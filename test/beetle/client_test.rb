require File.expand_path(File.dirname(__FILE__) + '/../test_helper')


module Beetle
  class ClientDefaultsTest < Test::Unit::TestCase
    def setup
      @client = Client.new
    end

    test "should have a default server" do
      assert_equal ["localhost:5672"], @client.servers
    end

    test "should have no additional subscription servers" do
      assert_equal [], @client.additional_subscription_servers
    end

    test "should have no exchanges" do
      assert @client.exchanges.empty?
    end

    test "should have no queues" do
      assert @client.queues.empty?
    end

    test "should have no messages" do
      assert @client.messages.empty?
    end

    test "should have no bindings" do
      assert @client.bindings.empty?
    end
  end

  class RegistrationTest < Test::Unit::TestCase
    def setup
      @client = Client.new
    end

    test "registering an exchange should store it in the configuration with symbolized option keys and force a topic queue and durability" do
      opts = {"durable" => false, "type" => "fanout"}
      @client.register_exchange("some_exchange", opts)
      assert_equal({:durable => true, :type => :topic}, @client.exchanges["some_exchange"])
    end

    test "should convert exchange name to a string when registering an exchange" do
      @client.register_exchange(:some_exchange)
      assert(@client.exchanges.include?("some_exchange"))
    end

    test "registering an exchange should raise a configuration error if it is already configured" do
      @client.register_exchange("some_exchange")
      assert_raises(ConfigurationError){ @client.register_exchange("some_exchange") }
    end

    test "registering a queue should automatically register the corresponding exchange if it doesn't exist yet" do
      @client.register_queue("some_queue", "durable" => false, "exchange" => "some_exchange")
      assert @client.exchanges.include?("some_exchange")
    end

    test "registering a queue should store key and exchange in the bindings list" do
      @client.register_queue(:some_queue, :key => "some_key", :exchange => "some_exchange")
      assert_equal([{:key => "some_key", :exchange => "some_exchange"}], @client.bindings["some_queue"])
    end

    test "registering an additional binding for a queue should store key and exchange in the bindings list" do
      @client.register_queue(:some_queue, :key => "some_key", :exchange => "some_exchange")
      @client.register_binding(:some_queue, :key => "other_key", :exchange => "other_exchange")
      bindings = @client.bindings["some_queue"]
      expected_bindings = [{:key => "some_key", :exchange => "some_exchange"}, {:key => "other_key", :exchange => "other_exchange"}]
      assert_equal expected_bindings, bindings
    end

    test "registering a queue should store it in the configuration with symbolized option keys and force durable=true and passive=false and set the amqp queue name" do
      @client.register_queue("some_queue", "durable" => false, "exchange" => "some_exchange")
      assert_equal({:durable => true, :passive => false, :auto_delete => false, :exclusive => false, :amqp_name => "some_queue"}, @client.queues["some_queue"])
    end

    test "registering a queue should add the queue to the list of queues of the queue's exchange" do
      @client.register_queue("some_queue", "durable" => true, "exchange" => "some_exchange")
      assert_equal ["some_queue"], @client.exchanges["some_exchange"][:queues]
    end

    test "registering two queues should add both queues to the list of queues of the queue's exchange" do
      @client.register_queue("queue1", :exchange => "some_exchange")
      @client.register_queue("queue2", :exchange => "some_exchange")
      assert_equal ["queue1","queue2"], @client.exchanges["some_exchange"][:queues]
    end

    test "registering a queue should raise a configuration error if it is already configured" do
      @client.register_queue("some_queue", "durable" => true, "exchange" => "some_exchange")
      assert_raises(ConfigurationError){ @client.register_queue("some_queue") }
    end

    test "should convert queue name to a string when registering a queue" do
      @client.register_queue(:some_queue)
      assert(@client.queues.include?("some_queue"))
    end

    test "should convert exchange name to a string when registering a queue" do
      @client.register_queue(:some_queue, :exchange => :murks)
      assert_equal("murks", @client.bindings["some_queue"].first[:exchange])
    end

    test "registering a message should store it in the configuration with symbolized option keys" do
      opts = {"persistent" => true, "queue" => "some_queue", "exchange" => "some_exchange"}
      @client.register_queue("some_queue", "exchange" => "some_exchange")
      @client.register_message("some_message", opts)
      assert_equal({:persistent => true, :queue => "some_queue", :exchange => "some_exchange", :key => "some_message"}, @client.messages["some_message"])
    end

    test "registering a message should raise a configuration error if it is already configured" do
      opts = {"persistent" => true, "queue" => "some_queue"}
      @client.register_queue("some_queue", "exchange" => "some_exchange")
      @client.register_message("some_message", opts)
      assert_raises(ConfigurationError){ @client.register_message("some_message", opts) }
    end

    test "registering a message should register a corresponding exchange if it hasn't been registered yet" do
      opts = { "exchange" => "some_exchange" }
      @client.register_message("some_message", opts)
      assert_equal({:durable => true, :type => :topic}, @client.exchanges["some_exchange"])
    end

    test "registering a message should not fail if the exchange has already been registered" do
      opts = { "exchange" => "some_exchange" }
      @client.register_exchange("some_exchange")
      @client.register_message("some_message", opts)
      assert_equal({:durable => true, :type => :topic}, @client.exchanges["some_exchange"])
    end

    test "should convert message name to a string when registering a message" do
      @client.register_message(:some_message)
      assert(@client.messages.include?("some_message"))
    end

    test "should convert exchange name to a string when registering a message" do
      @client.register_message(:some_message, :exchange => :murks)
      assert_equal("murks", @client.messages["some_message"][:exchange])
    end

    test "configure should yield a configurator configured with the client and the given options" do
      options = {:exchange => :foobar}
      Client::Configurator.expects(:new).with(@client, options).returns(42)
      @client.configure(options) {|config| assert_equal 42, config}
    end

    test "a configurator should forward all known registration methods to the client" do
      options = {:foo => :bar}
      config = Client::Configurator.new(@client, options)
      @client.expects(:register_exchange).with(:a, options)
      config.exchange(:a)

      @client.expects(:register_queue).with(:q, options.merge(:exchange => :foo))
      config.queue(:q, :exchange => :foo)

      @client.expects(:register_binding).with(:b, options.merge(:key => :baz))
      config.binding(:b, :key => :baz)

      @client.expects(:register_message).with(:m, options.merge(:exchange => :foo))
      config.message(:m, :exchange => :foo)

      @client.expects(:register_handler).with(:h, options.merge(:queue => :q))
      config.handler(:h, :queue => :q)

      assert_raises(NoMethodError){ config.moo }
    end
  end

  class ClientTest < Test::Unit::TestCase
    test "instantiating a client should not instantiate the subscriber/publisher" do
      Publisher.expects(:new).never
      Subscriber.expects(:new).never
      Client.new
    end

    test "should instantiate a subscriber when used for subscribing" do
      Subscriber.expects(:new).returns(stub_everything("subscriber"))
      client = Client.new
      client.register_queue("superman")
      client.register_message("superman")
      client.register_handler("superman", {}, &lambda{})
    end

    test "should instantiate a subscriber when used for publishing" do
      client = Client.new
      client.register_message("foobar")
      Publisher.expects(:new).returns(stub_everything("subscriber"))
      client.publish("foobar", "payload")
    end

    test "should delegate publishing to the publisher instance" do
      client = Client.new
      client.register_message("deadletter")
      args = ["deadletter", "x", {:a => 1}]
      client.send(:publisher).expects(:publish).with(*args).returns(1)
      assert_equal 1, client.publish(*args)
    end

    test "should convert message name to a string when publishing" do
      client = Client.new
      client.register_message("deadletter")
      args = [:deadletter, "x", {:a => 1}]
      client.send(:publisher).expects(:publish).with("deadletter", "x", :a => 1).returns(1)
      assert_equal 1, client.publish(*args)
    end

    test "should convert message name to a string on rpc" do
      client = Client.new
      client.register_message("deadletter")
      args = [:deadletter, "x", {:a => 1}]
      client.send(:publisher).expects(:rpc).with("deadletter", "x", :a => 1).returns(1)
      assert_equal 1, client.rpc(*args)
    end

    test "trying to publish an unknown message should raise an exception" do
      assert_raises(UnknownMessage) { Client.new.publish("foobar") }
    end

    test "trying to RPC an unknown message should raise an exception" do
      assert_raises(UnknownMessage) { Client.new.rpc("foobar") }
    end

    test "should delegate stop_publishing to the publisher instance" do
      client = Client.new
      client.send(:publisher).expects(:stop)
      client.stop_publishing
    end

    test "should delegate queue purging to the publisher instance" do
      client = Client.new
      client.register_queue(:queue)
      client.send(:publisher).expects(:purge).with("queue").returns("ha!")
      assert_equal "ha!", client.purge("queue")
    end

    test "purging a queue should convert the queue name to a string" do
      client = Client.new
      client.register_queue(:queue)
      client.send(:publisher).expects(:purge).with("queue").returns("ha!")
      assert_equal "ha!", client.purge(:queue)
    end

    test "trying to purge an unknown queue should raise an exception" do
      assert_raises(UnknownQueue) { Client.new.purge(:mumu) }
    end

    test "should delegate rpc calls to the publisher instance" do
      client = Client.new
      client.register_message("deadletter")
      args = ["deadletter", "x", {:a => 1}]
      client.send(:publisher).expects(:rpc).with(*args).returns("ha!")
      assert_equal "ha!", client.rpc(*args)
    end

    test "should delegate listening to the subscriber instance" do
      client = Client.new
      client.register_queue(:a)
      client.register_message(:a)
      client.register_queue(:b)
      client.register_message(:b)
      client.send(:subscriber).expects(:listen).with(["a", "b"]).yields
      x = 0
      client.listen([:a, "b"]) { x = 5 }
      assert_equal 5, x
    end

    test "trying to listen to an unknown message should raise an exception" do
      assert_raises(UnknownMessage) { Client.new.listen([:a])}
    end

    test "should delegate stop_listening to the subscriber instance" do
      client = Client.new
      client.send(:subscriber).expects(:stop!)
      client.stop_listening
    end

    test "should delegate handler registration to the subscriber instance" do
      client = Client.new
      client.register_queue("huhu")
      client.send(:subscriber).expects(:register_handler)
      client.register_handler("huhu")
    end

    test "should convert queue names to strings when registering a handler" do
      client = Client.new
      client.register_queue(:haha)
      client.register_queue(:huhu)
      client.send(:subscriber).expects(:register_handler).with(["huhu", "haha"], {}, nil)
      client.register_handler([:huhu, :haha])
    end

    test "should use the configured logger" do
      client = Client.new
      Beetle.config.expects(:logger)
      client.logger
    end

    test "load should expand the glob argument and evaluate each file in the client instance" do
      client = Client.new
      File.expects(:read).returns("1+1")
      client.expects(:eval).with("1+1",anything,anything)
      client.load("#{File.dirname(__FILE__)}/../../**/client_test.rb")
    end

    test "tracing should modify the amqp options for each queue and register a handler for each queue" do
      client = Client.new
      client.register_queue("test")
      sub = client.send(:subscriber)
      sub.expects(:register_handler).with(client.queues.keys, {}, nil).yields(stub_everything("message"))
      sub.expects(:listen)
      client.stubs(:puts)
      client.trace
      test_queue_opts = client.queues["test"]
      expected_name = client.send :queue_name_for_tracing, "test"
      assert_equal expected_name, test_queue_opts[:amqp_name]
      assert test_queue_opts[:auto_delete]
      assert !test_queue_opts[:durable]
    end

  end
end
