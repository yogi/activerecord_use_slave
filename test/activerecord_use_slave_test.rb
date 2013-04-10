require 'test/unit'
require 'active_record'
require 'activerecord_use_slave'
require 'thread'
require 'pp'

ENV["RAILS_ENV"] = "test"

ROOT = File.expand_path("../..", __FILE__)
CONFIG = YAML.load(IO.read(ROOT + "/db/config.yml"))
ActiveRecord::Base.configurations = CONFIG
ActiveRecord::Base.establish_connection(CONFIG["test"])

class Message < ActiveRecord::Base
end

class ExcludedEntity < ActiveRecord::Base

end

class ActiveRecordSwitchConnectionTest < Test::Unit::TestCase
  def setup
    ExcludedEntity.delete_all
    Message.delete_all
    Message.create!
  end

  def test_using_connection_requires_a_block
    assert_raise_message("block required") { ActiveRecord::Base.using_connection(:test) }
  end

  def test_using_connection_should_switch_connections
    assert_equal 1, Message.count
    ActiveRecord::Base.using_connection :test_slave do
      assert_equal 0, Message.count, "should be using slave-db, which shouldn't have any rows"
    end
    assert_false ActiveRecord::Base.connection_handler(:test_slave).active_connections?, "switched connection should be returned to pool"
    assert_true ActiveRecord::Base.connection_handler.active_connections?, "default pool's connection should not be closed"
  end

  def test_using_connection_should_switch_connections_even_if_its_the_same_as_the_original
    assert_equal 1, Message.count
    entered_block = false
    ActiveRecord::Base.using_connection :test do
      assert_equal 1, Message.count, "should be using master-db"
      entered_block = true
    end
    assert_true entered_block, "didn't enter using_connection block"
  end

  def test_using_slave_should_infer_the_connection_spec_from_current_env
    assert_equal 1, Message.count
    ActiveRecord::Base.using_slave do
      assert_equal 0, Message.count, "should be using slave-db, which shouldn't have any rows"
    end
  end

  def test_using_connection_should_switch_connections_only_for_that_thread
    assert_equal 1, Message.count

    mutex = Mutex.new
    cond = ConditionVariable.new

    slave_thread = Thread.new do
      mutex.synchronize do
        ActiveRecord::Base.using_connection :test_slave do
          cond.wait mutex
          assert_equal 0, Message.count, "should be using slave-db, which shouldn't have any rows"
        end
      end
    end

    sleep 0.1 # ensure slave_thread acquires the mutex

    master_thread = Thread.new do
      mutex.synchronize do
        assert_equal 1, Message.count, "should be using test-db concurrently, which should have 1 message"
        cond.signal
      end
    end

    master_thread.join
    slave_thread.join
    assert_equal 1, Message.count, "should be using test-db, which should have 1 message"
  end

  def test_should_exclude_models_which_should_not_be_switched
    ActiveRecord::Base.peg_models_to_default_connection(ExcludedEntity)

    ExcludedEntity.create!
    ActiveRecord::Base.using_connection :test do
      assert_equal 1, ExcludedEntity.count, "should be using default-db"
    end

    ActiveRecord::Base.using_connection :test_slave do
      assert_equal 1, ExcludedEntity.count, "should be using default-db"
    end
  end
end