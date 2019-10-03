require 'terminal-table'

class TablePrinter
  def initialize(url)
    @url = url
  end

  def print_table(data, headings = [], title = nil)
    puts Terminal::Table.new(rows: data, headings: headings, title: title)
    puts "Total: #{data.count}"
    puts
  end

  def print_laptop_url(laptop_id)
    puts "Link: #{ @url }hardware/#{ laptop_id }"
  end
end
