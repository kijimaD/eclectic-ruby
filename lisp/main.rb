class Cons
  attr_reader :car, :cdr
  def initialize(car, cdr)
    @car, @cdr = car, cdr
  end
end

# d = Cons.new(1, Cons.new(2, Cons.new(3, :nil)))
# p d.car
# p d.cdr
# p d.cdr.cdr.car

class Env
  def initialize(parent=nil, defaults={})
    @parent = parent
    @defs = defaults
  end

  def define(symbol, value)
    @defs[symbol] = value
    return value
  end

  def defined?(symbol)
    return true if @defs.has_key?(symbol)
    return false if @parent.nil?
    return @parent.defined?(symbol)
  end

  def lookup(symbol)
    return @defs[symbol] if @defs.has_key?(symbol)
    raise "No value for symbol #{symbol}" if @parent.nil?
    return @parent.lookup(symbol)
  end
end

# e = Env.new
# p e.defined?(:var)
# p e.define(:var, 1)
# p e.defined?(:var)

# e = Env.new
# p e.define(:var, 1)
# p e.lookup(:var)
# p e.lookup(:var, 2) # No value!
