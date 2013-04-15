require 'connection_stack'

class ActiveRecord::Base
  class << self
    # stores 1 connection_handler for each db so that there is a readily available connection-pool for that db
    @@connection_handlers_by_db ||= {}

    # stores the models that should be pegged to the default connection
    @@excluded_models ||= {}

    alias_method :orig_connection_handler, :connection_handler

    def peg_models_to_default_connection(*models)
      models.each do |model|
        @@excluded_models[model] = true
      end
    end

    # Return a db-specific connection-handler if the flag is set, otherwise return the default one
    #
    def connection_handler(spec_symbol = nil)
      return @@connection_handlers_by_db[spec_symbol] if spec_symbol
      if !@@excluded_models.include?(self) && ConnectionStack.active?
        @@connection_handlers_by_db[ConnectionStack.peek] ||= ActiveRecord::ConnectionAdapters::ConnectionHandler.new
      else
        orig_connection_handler
      end
    end

    # Switches ActiveRecord::Base connection-handler to the specific connection e.g. :test, :production, etc, and ensures
    # that all ActiveRecord classes connect to the specified database within the passed in block
    #
    #   ActiveRecord::Base.using_connection(:test_slave) { Person.find }
    #
    def using_connection(db)
      raise "block required" unless block_given?

      ConnectionStack.push db

      unless ActiveRecord::Base.connection_handler.retrieve_connection_pool(ActiveRecord::Base)
        ActiveRecord::Base.establish_connection(db)
      end

      yield

    ensure
      ActiveRecord::Base.connection_handler.clear_active_connections! rescue puts "ignoring error in clear_active_connections: #{$!.class} #{$!.message}"
      ConnectionStack.pop
    end

    # Switches the connection to the slave db, which is infered from the current environment. Example, given the following
    # database configuration:
    #
    #   {
    #      'production' => {
    #         'adapter'  => 'mysql',
    #         'database' => 'prod'
    #      },
    #      'production_slave' => {
    #         'adapter'  => 'mysql',
    #         'database' => 'prod_slave'
    #      }
    #   }
    #
    # The following code uses "production_slave" if RAILS_ENV is "production"
    #
    #   ActiveRecord::Base.using_slave { Person.find }
    def using_slave(&blk)
      env = ENV['PADRINO_ENV'] || ENV['RAILS_ENV'] || ENV['RACK_ENV'] || ENV['DB'] || 'development'
      using_connection("#{env}_slave", &blk)
    end
  end
end
