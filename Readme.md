# activerecord_use_slave

Forces ActiveRecord to use a different connection for the duration of a block.

This can be used, for example, to serve an entire controller request from a slave database.

## Usage

### using_connection

```ruby
ActiveRecord::Base.using_connection :production_slave do
    # usual activerecord code goes here
    Person.find_by_email params[:email]
end
```

In the above code all ActiveRecord classes switch to using the prod_slave database.
Once the block completes, these revert to their original connections.


### using_slave

Alternatively the db could be inferred as a slave:

```ruby
# given the following database configuration and RAILS_ENV being "production":

{
    'production' => {
        'adapter' => 'mysql',
        'database' => 'prod'
    },
    'production_slave' => {
        'adapter' => 'mysql',
        'database' => 'prod_slave'
    }
}

# this uses "production_slave"
ActiveRecord::Base.using_slave do
    # ...
end
```

In the above example, the slave db is inferred from the current environment: ENV["RAILS_ENV" || ENV["PADRINO_ENV"] || ENV["RACK_ENV"]).
If any of these is set, the slave is assumed to be "<env>_slave".




