require 'terminal-table'

class TablePrinter
  def initialize(url)
    @url = url
  end

  def print_table(data, headings = [])
    puts Terminal::Table.new(rows: data, headings: headings)
    puts "Total: #{data.count}"
  end

  def print_laptop_url(laptop_id)
    puts "Link: #{ @url }hardware/#{ laptop_id }"
  end
end
