require_relative 'change_maker'

class Customer
  attr_reader :denoms, :coins

  def self.us(*coins)
    self.new([1, 5, 10, 25], *coins)
  end

  def initialize(denoms, *coins)
    @coins = coins.sort
    @denoms = denoms.sort

    coins.each{ |denom| check_denom(denom) }

    @cm = ChangeMaker.new(*@denoms)
    check_optimal_start
  end

  def check_denom(denom)
    raise "Bad denomination #{denom}" unless denoms.include?(denom)
  end

  def amount
    coins.sum
  end

  def number
    coins.size
  end

  def ==(other)
    return false unless other.kind_of?(Customer)
    return false unless coins == other.coins
    return false unless denoms == other.denoms
    return true
  end

  def to_s
    dollars = sprintf("$%.2f", amount.to_f/100)
    return "#{dollars} (#{coins.join(', ')}"
  end
end

customer1 = Customer.us(1, 5)
