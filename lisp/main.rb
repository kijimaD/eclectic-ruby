require 'pry-byebug'
require 'sexp'
# RubyコードをS式にparseするgem
# 依存gemの`rparsec`のコードでsyntaxエラーになってるので修正が必要。syntaxエラーだからオーバーライド不可
# (parser.rb のas_numメソッド)

# class RParsec::Parser
#   def as_num c
#     case c
#     when String
#       c[0]
#     else
#       c
#     end
#   end
# end

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

  # なぜか sample になかったので追加
  def self.from_a(args)
    # ARGSからリストを作る
    head, *tail = args
    return :nil unless head
    new(head, from_a(tail))
    # p Cons.from_a([1, 2, 3]) # => #<Cons:0x000055866c6965c0 @car=1, @cdr=#<Cons:0x000055866c696610 @car=2, @cdr=#<Cons:0x000055866c696660 @car=3, @cdr=:nil>>>
  end

  def initialize(car, cdr)
    @car, @cdr = car, cdr
  end
  # d = Cons.new(1, Cons.new(2, Cons.new(3, :nil)))
  # p d.car
  # p d.cdr
  # p d.cdr.cdr.car

  def lispeval(env, forms)
    return forms.lookup(car).call(env, forms, *cdr.arrayify) if forms.defined?(car)
    func = car.lispeval(env, forms)

    return func unless func.class == Proc # MEMO: 3.call として失敗するため
    return func.call(*cdr.arrayify.map do |x|
                       result = x.lispeval(env, forms)
                       result = eval(result).join if result.class == String
                       result
                     end)
    # MEMO: "111" が "[\"1\", \"1\", \"1\"]" になるのを防ぐため、パース直後に"[...]"を除去している。
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

  def to_sexp
    return "(cons #{car.to_sexp} #{cdr.to_sexp})" unless conslist?
    return "(#{arrayify.map{ |x| x.to_sexp }.join(' ')})"
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
  # パースしたS式が配列で返ってくるので、Consオブジェクトに変換する。
  def consify
    map{ |x| x.consify }.reverse.inject(:nil) { |cdr, car| Cons.new(car, cdr) }
  end
end

class Lambda
  def initialize(env, forms, params, *code)
    @env = env
    @forms = forms
    @params = params.arrayify
    @code = code
  end

  def call(*args)
    raise "Expected #{@params.size} arguments!" unless args.size == @params.size
    newenv = Env.new(@env)
    newforms = Env.new(@forms)
    @params.zip(args).each do |sym, value|
      newenv.define(sym, value)
    end
    @code.map{ |c| c.lispeval(newenv, newforms) }.last
  end
  # l = Lambda.new(Env.new, Env.new, :nil, 1.0)
  # p l.call # 1.0

  def to_sexp
    "(lambda #{@params.to_sexp} #{@code.map{ |x| x.to_sexp }.join(' ')}"
  end
  # l = Lambda.new(Env.new, Env.new, :nil, 1.0)
  # p l.to_sexp # "(lambda () 1.0"

  def to_proc
    return lambda{ |*args| self.call(:args) }
  end
end

DEFAULTS = {
  :nil => :nil,
  :t => :t,
  :+ => lambda { |x, y| x + y },
  :- => lambda { |x, y| x - y },
  :* => lambda { |x, y| x * y },
  :/ => lambda { |x, y| x / y },
  :car => lambda { |x| x.car },
  :cdr => lambda { |x| x.cdr },
  :cons => lambda { |x, y| Cons.new(x, y) },
  :atom? => lambda { |x| x.kind_of?(Cons) ? :nil : :t },
  :eq? => lambda { |x, y| x.equal?(y) ? :t : :nil },
  :list => lambda { |*args| Cons.from_a(args)},
  :print => lambda { |*args| puts *args; :nil },
}

# 特殊な引数の順番、評価しないことが必要なためのspecial form
FORMS = {
  :quote => lambda { |env, forms, exp| exp }, # 評価せず返す
  :define => lambda { |env, forms, sym, value|
    env.define(sym, value.lispeval(env, forms))
  },
  :set! => lambda { |env, forms, sym, value|
    env.set(sym, value.lispeval(env, forms))
  },
  :if => lambda { |env, forms, cond, xthen, xelse|
    if cond.lispeval(env, forms) != :nil
      xthen.lispeval(env, forms)
    else
      xelse.lispeval(env, forms)
    end
  },
  :lambda => lambda { |env, forms, params, *code|
    Lambda.new(env, forms, params, *code)
  },

  # FIXME: ネストすると動かない
  :funcall => lambda { |env, forms, exp, params|
    body = exp.lispeval(env, forms)
    if params == :nil
      body.call
    else
      body.call(*params.arrayify)
    end
  },
  # (define plus (lambda (x) (+ x 2))) (funcall plus (2))

  :let1 => lambda { |env, forms, binding, body|
    Lambda.new(env, forms, [binding.car], body).call(binding.cdr.car.lispeval(env, forms))
  },
  # (let1 (a 4) (+ a 1)) ;=> 4

  :defmacro => lambda { |env, forms, name, exp|
    func = exp.lispeval(env, forms)
    forms.define(name, lambda{ |env2, forms2, *rest| func.call(*rest).lispeval(env, forms) })
    name
  },
  # (defmacro let1 (lambda (binding body) (list (list (quote lambda) (list (car binding)) body) (car (cdr binding)))))
  # (defmacro unless (lambda (cond then else) (list (quote if) cond else then)))

  :eval => lambda { |env, forms, *code|
    code.map{ |c| c.lispeval(env, forms)}.map{ |c| c.lispeval(env, forms) }.last
  },
  # (eval (quote (+ 1 2))) => 3

  :letmacro => lambda { |env, forms, binding, body|
    name = binding.car
    func = binding.cdr.car.lispeval(env, forms)
    newforms = Env.new(forms)
    newforms.define(name, lambda{ |env2, form2, *rest| func.call(*rest).lispeval(env, forms)})
    body.lispeval(env, newforms)
  },
  # (letmacro (myquote (lambda (thing) (list (quote quote) thing))) (myquote b))
  # (myquote b) ; ERROR: No value for symbol myquote. =>  So, lexical macro!

  :ruby => lambda { |env, forms, name|
    Kernel.const_get(name)
  },

  :"!" => lambda { |env, forms, object, message, *params|
    evaled_params = params.map do |p|
      result = p.lispeval(env, forms).arrayify
      eval(result).join if result.class == String
    end
    proc = nil
    proc = evaled_params.pop if evaled_params.last.kind_of?(Lambda) # 最後の引数がlambdaならブロックスロットに入る。
    object.lispeval(env, forms).send(message, *evaled_params, &proc).consify
  }, # FIXME: not working ... params => ["[\"l\", \"i\", \"s\", \"p\", \".\", \"r\", \"b\"]"]
  # (define f (! (ruby File) open "lisp.rb"))
  # (define lines (! f readlines))
  # (! f close)

  # (! (ruby Kernel) puts "aaa")
}

class Interpreter
  def initialize(defaults=DEFAULTS, forms=FORMS)
    @env = Env.new(nil, defaults)
    @forms = Env.new(nil, forms)
  end

  def eval(string)
    # 文字列のときの扱いがおかしい。
    # "122".parse_sexp
    # => 122 だが、
    # "\"122\"".parse_sexp
    # => ["[\"1\", \"2\", \"2\"]"] となる。
    exps = "(#{string})".parse_sexp
    exps.map do |exp|
      exp.consify.lispeval(@env, @forms)
    end.last
  end
  # lisp = Interpreter.new
  # p lisp.eval("(+ 1 2)")

  def repl
    print "> "
    STDIN.each_line do |line|
      begin
        puts self.eval(line).to_sexp
      rescue StandardError => e
        puts "ERROR: #{e}"
      end
      print "> "
    end
  end
  # Interpreter.new.repl
end

# p lisp.eval('(list 122 "111" "aaa")')

code = <<EOF
  (define omikuji (lambda (kujis)
  (let1 (pull-func (lambda () (pop kujis)))
  (let1 (shuffle-func (lambda () (set! kujis 0)))
    (lambda (type)
      (if (eq? type (quote pull)) (funcall pull-func))
      (if (eq? type (quote shuffle)) (funcall shuffle-func)))))))
EOF
lisp = Interpreter.new
lisp.eval(code)
lisp.repl

# (funcall (funcall omikuji (quote 1 2 3)) (quote pull))

# Interpreter.new.repl

# 目標(Emacs Lispでの例)

# (setq lexical-binding t)

# (defun omikuji (kujis)
#   (let* ((kujis kujis)
#          (pull-func (lambda () (cdr (pop kujis))))
#          (shuffle-func (lambda () (setq kujis nil))))
#     (lambda (type)
#       (cond ((eq type 'pull) (funcall pull-func))
#             ((eq type 'shuffle) (funcall shuffle-func))))))

# (defun make-ji (num key name)
#   (make-list num `(,key  . ,name)))
# (make-ji 10 'daikiti "大吉")

# (setq kuji2022
#       (omikuji (append (make-ji 10 'daikiti  "大吉")
#                        (make-ji 20 'syokichi "中吉")
#                        (make-ji 30 'syokichi "小吉")
#                        (make-ji 30 'suekichi "末吉")
#                        (make-ji 10 'kyo      "凶"))))

# (funcall kuji2022 'shuffle)
# (funcall kuji2022 'pull)
