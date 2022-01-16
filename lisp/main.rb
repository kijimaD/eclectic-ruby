require 'sexp'

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
  # e = Env.new
  # p e.defined?(:var) # false
  # p e.define(:var, 1) # true
  # p e.defined?(:var) # true

  def lookup(symbol)
    return @defs[symbol] if @defs.has_key?(symbol)
    raise "No value for symbol #{symbol}" if @parent.nil?
    return @parent.lookup(symbol)
  end
  # e = Env.new
  # p e.define(:var, 1) # 1
  # p e.lookup(:var) # 1
  # p e.lookup(:var, 2) # No value!

  def set(symbol, value)
    if @defs.has_key?(symbol)
      @defs[symbol] = value
    elsif @parent.nil?
      raise "No definition of #{symbol} to set to #{value}"
    else
      @parent.set(symbol, value)
    end
  end
  # e = Env.new
  # p e.define(:var, 1) # 1
  # p e.set(:var, 2) # 2
  # p e.lookup(:var) # 2
end

class Cons
  attr_reader :car, :cdr

  def initialize(car, cdr)
    @car, @cdr = car, cdr
  end
  # d = Cons.new(1, Cons.new(2, Cons.new(3, :nil)))
  # p d.car
  # p d.cdr
  # p d.cdr.cdr.car

  def lispeval(env, forms)
    return forms.lookup(car).call(env, forms, *cdr.arrayify) if forms&.defined?(car)
    func = car.lispeval(env, forms)

    return func unless func.class == Proc # MEMO: 3.call として失敗してたので修正
    return func.call(*cdr.arrayify.map{ |x| x.lispeval(env, forms) })
  end
  # env = Env.new(nil, {:+ => lambda{ |x, y| x + y } })
  # p Cons.new(:+, Cons.new(1, Cons.new(2, :nil))).lispeval(env, nil)

  def arrayify
    return self unless conslist?
    return [car] + cdr.arrayify
  end

  def conslist?
    cdr.conslist?
  end
end

class Object
  def lispeval(env, forms)
    self
  end

  def consify
    self
  end

  def arrayify
    self
  end

  def conslist?
    false
  end
end
# p 1.lispeval(nil, nil) # 1
# p "foo".lispeval(nil, nil) # foo

class Symbol
  def lispeval(env, forms)
    # unquoted symbols evaluate to the value stored in the environment under thair name.
    env.lookup(self)
  end
  # e = Env.new
  # e.define(:a, 1)
  # p :a.lispeval(e, nil) # 1
  # p :b.lispeval(e, nil) # RuntimeError

  def arrayify
    self == :nil ? [] : self
  end

  def conslist?
    self == :nil
  end
end

class Array
  def consify
    map{ |x| x.consify }.reverse.inject(:nil) { |cdr, car| Cons.new(car, cdr) }
  end
end

# pp "(+ 1 2)".parse_sexp.consify
# env = Env.new(nil, {:+ => lambda{ |x, y| x + y }})
# p "(+ 1 2)".parse_sexp.consify.lispeval(env, nil)
