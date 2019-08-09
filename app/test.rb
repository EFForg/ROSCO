require 'httparty'
require 'terminal-table'

class SnipeAPI

  LAPTOP_CATEGORY_ID = 1

  def initialize
    load_key
    @base_url = 'https://snipeit.app.eff.org/api/v1/'
  end

  def error(message)
    raise "ERROR: #{message}"
  end

  def load_key
    path = '/secrets/api_key.txt'
    @@access_token ||= begin
      if not File.exist?(path)
        self.error('Missing api key')
      end
      File.read(path)
    end
  end

  def query(url, query = {}, offset = 0)
    headers = {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{ @@access_token }",
    }

    query["offset"] = offset if offset > 0
    response = HTTParty.get(@base_url + url, query: query, headers: headers)

    row_count = response['rows'].count
    if response.code != 200
      self.error(__method__.to_s)
    elsif row_count > 0
      next_response = self.query(url, query, offset + row_count)
      response['rows'] += next_response['rows'] if next_response.code == 200
    end
    response
  end

  def print_table(data, headings)
    puts Terminal::Table.new(
      :rows => data,
      :headings => headings
    )
    puts "Total: #{data.count}"
  end

  # --------------------------------------------------------
  # Laptop lists
  # --------------------------------------------------------

  # Return all laptops that are not in the archived Snipe state
  def get_active_laptops
    if @active_laptops.nil?
      response = self.query('hardware', {'category_id' => LAPTOP_CATEGORY_ID})
      @active_laptops = response['rows']
    else
      @active_laptops
    end
  end

  # Return all non-archived spare laptops
  def get_spare_laptops
    if @spare_laptops.nil?
      response = self.query('hardware', {'category_id' => LAPTOP_CATEGORY_ID, 'status' => 'Requestable'})
      @spare_laptops = response['rows']
    else
      @spare_laptops
    end
  end

  # Return all laptops that are not spares, regardless of current check out status
  def get_staff_laptops
    if @staff_laptops.nil?
      all = get_active_laptops
      spares = get_spare_laptops

      spare_ids = spares.collect{|i| i["id"]}
      @staff_laptops = all.reject{|i| spare_ids.include?(i["id"])}
    else
      @staff_laptops
    end
  end

  def get_laptops(type)
    if type == 'spares'
      return self.get_spare_laptops
    elsif type == 'staff'
      return self.get_staff_laptops
    else
      return self.get_active_laptops
    end
  end

  # --------------------------------------------------------
  # Laptop Queries
  # --------------------------------------------------------

  # Return a table of in-warranty laptops.
  #
  # @param [String] fleet_type Can be 'all', 'spares', 'staff'
  def get_laptop_fleet(fleet_type)
    laptops = get_laptops(fleet_type)
    data = laptops.sort_by{|i| i['asset_tag']}
      .map{|i| [i['asset_tag'], i['serial'], i['name']]}
    print_table(data, ['Asset Tag', 'Serial', 'Asset Name'])
  end

  # Return a table of in-warranty laptops.
  #
  # @param [String] fleet_type Can be 'all', 'spares', 'staff'
  def get_laptops_in_warranty(fleet_type)
    laptops = get_laptops(fleet_type)
    data = laptops.reject{|i| i['warranty_expires'].nil? or Date.parse(i['warranty_expires']['date']) < DateTime.now}
      .sort_by{|i| i['warranty_expires']['date']}
      .map{|i| [i['warranty_expires']['date'], i['asset_tag'], i['serial'], i['name']]}
    print_table(data, ['Warranty Expires', 'Asset Tag', 'Serial', 'Asset Name'])
  end

  # Return a table of laptops sorted by age.
  # Age is approximate. This method does not calculate the intricacies of leap years, etc.
  #
  # @param [String] fleet_type Can be 'all', 'spares', 'staff'
  # @param [Float] older_than_years Filter out results that are newer than the approx years given
  def get_laptops_by_age(fleet_type, older_than_years = 0.0)
    laptops = get_laptops(fleet_type)
    data = []

    # Do not include these very old assets if filtering by age
    if older_than_years == 0.0
      # Format assets that have word based asset_tags, such as 'oldspare03'
      data += laptops.reject{|i| i["asset_tag"].to_i != 0}
        .sort_by{|i| i["asset_tag"]}
        .map{|i| ["---", "---", i["asset_tag"], i["serial"], i["name"]]}

      # Format assets that are so old the asset_tags increment from '000000001' and up
      data += laptops.reject{|i| i["asset_tag"].to_i == 0 or i["asset_tag"].to_i > 100}
        .sort_by{|i| i["asset_tag"]}
        .map{|i| ["---", "---", i["asset_tag"], i["serial"], i["name"]]}
    end

    # Format assets that have date-based asset_tags (default asset_tag structure)
    date_asset_tags = laptops.reject{|i| i["asset_tag"].to_i == 0 or i["asset_tag"].to_i <= 100}

    # Filter date-based asset_tags based on approx age
    if older_than_years != 0.0
      date_asset_tags = date_asset_tags.reject{|i| ((Date.today - Date.parse(i["asset_tag"]))/365.0).round(3) < older_than_years}
    end

    data += date_asset_tags.sort_by{|i| i["asset_tag"]}
      .map{|i| [Date.parse(i["asset_tag"]).strftime('%Y-%m-%d'), ((Date.today - Date.parse(i["asset_tag"]))/365.0).round(3), i["asset_tag"], i["serial"], i["name"]]}

    print_table(data, ['Purchase Date', 'Approx Age', 'Asset Tag', 'Serial', 'Asset Name'])
  end

  def get_laptops_by_status(fleet_type, status = nil, type = false)
    laptops = get_laptops(fleet_type)
    status_field = type ? 'status_type' : 'name'
    if not status.nil?
      laptops = laptops.reject{|i| i['status_label'][status_field] != status}
    end
    data = laptops.sort_by{|i| i['status_label'][status_field]}
        .map{|i| [i['status_label'][status_field], i["asset_tag"], i["serial"], i["name"]]}
    print_table(data, ['Status', 'Asset Tag', 'Serial', 'Asset Name'])
  end

  # --------------------------------------------------------
  # Status Queries
  # --------------------------------------------------------

  def get_statuses
    response = self.query('statuslabels')
    data = response['rows'].sort_by{|i| i['type']}
      .map{|i| [i['id'], i['type'], i['name']]}
    print_table(data, ['ID', 'Type', 'Name'])
  end
end
