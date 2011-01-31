require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

module Beetle
  # slightly different than the Redis version, here we're testing that the mongo implementation
  # will behave like the redis implemenation
  class MongoImplAssumptionsTest < Test::Unit::TestCase
    def setup
      @mdds = MongoDeduplicationStore.new
      @mdds.drop_collection_only_for_tests_danger_will_robinson_danger!

      @msg_id = Beetle::UUID.uuid
      @mdds.prepare(@msg_id)
    end

    test "trying to delete a non existent key doesn't throw an error" do
      assert !@mdds.del(@msg_id, :bogus)
      assert !@mdds.get(@msg_id, :bogus)
    end

    test "msetnx updates the document if no keys are set" do
      assert_equal 1, @mdds.msetnx(@msg_id, { "a" => 1, "b" => 2 })

      doc = @mdds.collection.find_one(:_id => @msg_id)

      assert_equal 1, doc['a']
      assert_equal 2, doc['b']
    end

    test "msetnx does not update the document if any keys are set" do
      @mdds.collection.update({ :_id => @msg_id }, { "a" => 3 })

      assert_equal 0, @mdds.msetnx(@msg_id, { "a" => 1, "b" => 2 })
    end

    test "msetnx returns 0 or 1" do
      assert_equal 1,   @mdds.msetnx(@msg_id, { "a" => 1, "b" => 2 })
      assert_equal "1", @mdds.get(@msg_id, "a")
      assert_equal "2", @mdds.get(@msg_id, "b")
      assert_equal 0,   @mdds.msetnx(@msg_id, { "a" => 3, "b" => 4 })
      assert_equal "1", @mdds.get(@msg_id, "a")
      assert_equal "2", @mdds.get(@msg_id, "b")
    end

    test "incr returns the new value of the key" do
      @mdds.collection.update({ :_id => @msg_id }, { :foo => 3 }, { :safe => true })

      assert_equal 4, @mdds.incr(@msg_id, :foo)
    end

    test "get always returns a string for an existing key" do   # ugh!
      @mdds.collection.update({ :_id => @msg_id }, { :foo => 3 }, { :safe => true })

      assert_equal '3', @mdds.get(@msg_id, 'foo')
    end

    test "get returns nil for a key that doesn't exist" do
      assert_nil @mdds.get(@msg_id, 'foo')
    end
  end
end


