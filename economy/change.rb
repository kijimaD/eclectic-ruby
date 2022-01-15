class Prices
  def initialize(*data)
    @data = data
  end

  def each(count)
    count.times { yield get }
  end

  def get
    @data[rand(@data.size)]
  end
end

price_list = IO.readlines("prices.txt").map{ |price| price.to_i }
prices = Prices.new(price_list)
prices.each(4) { |price| price_list.push price }
p price_list
