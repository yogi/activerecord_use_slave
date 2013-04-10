
class ConnectionStack
  class << self
    def stack
      (Thread.current[:activerecord_use_slave] ||= [])
    end

    def push(db)
      stack.push db
    end

    def pop
      stack.pop
    end

    def peek
      stack.last
    end

    def active?
      stack.any?
    end
  end
end