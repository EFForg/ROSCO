require 'httparty'
require 'terminal-table'

class SnipeAPI
  LAPTOP_CATEGORY_ID = 1
  DEPRECIATION_PERIOD = 4.0 # in years
  BASE_URL = 'https://snipeit.app.eff.org/'
  API_URL = "#{ BASE_URL }api/v1/"

  def initialize
    load_key
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

    query['offset'] = offset if offset > 0
    response = HTTParty.get(API_URL + url, query: query, headers: headers)

    if response.code != 200
      self.error(__method__.to_s)
    elsif not response.key?('rows')
      return response
    elsif (row_count = response['rows'].count) > 0
      next_response = self.query(url, query, offset + row_count)
      response['rows'] += next_response['rows'] if next_response.code == 200
    end
    response
  end

  def print_table(data, headings = [])
    puts Terminal::Table.new(rows: data, headings: headings)
    puts "Total: #{data.count}"
  end

  def print_laptop_url(laptop_id)
    puts "Link: #{ BASE_URL }hardware/#{ laptop_id }"
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

      spare_ids = spares.map{|i| i['id']}
      @staff_laptops = all.reject{|i| spare_ids.include?(i['id'])}
    else
      @staff_laptops
    end
  end

  # Return all laptops that are in the archived Snipe state
  def get_archived_laptops
    if @archived_laptops.nil?
      response = self.query('hardware', {'category_id' => LAPTOP_CATEGORY_ID, 'status' => 'Archived'})
      @archived_laptops = response['rows']
    else
      @archived_laptops
    end
  end

  def get_laptops(type)
    if type == 'spares'
      return self.get_spare_laptops
    elsif type == 'staff'
      return self.get_staff_laptops
    elsif type == 'archived'
      return self.get_archived_laptops
    else
      return self.get_active_laptops
    end
  end

  # --------------------------------------------------------
  # User lists
  # --------------------------------------------------------

  def get_users
    if @users.nil?
      response = self.query('users')
      @users = response['rows']
    else
      @users
    end
  end

  # --------------------------------------------------------
  # Laptop Helpers
  # --------------------------------------------------------

  # Get one laptop by asset_tag
  def get_laptop(asset_tag)
    self.query("hardware/bytag/#{asset_tag}")
  end

  def calculate_asset_age(asset)
    # Return nil if the asset has a non-date-based asset_tag
    return nil if asset['asset_tag'].to_i == 0 or asset['asset_tag'].to_i < 100

    ((Date.today - Date.parse(asset['asset_tag']))/365.0).round(3)
  end

  # --------------------------------------------------------
  # Laptop Queries
  #
  # fleet_type Can be: 'all', 'spares', 'staff', 'archived'
  # --------------------------------------------------------

  # Return a table of in-warranty laptops.
  def print_laptops(fleet_type)
    laptops = get_laptops(fleet_type)
    data = laptops.sort_by{|i| i['asset_tag']}
      .map{|i| [i['asset_tag'], i['serial'], i['name']]}
    print_table(data, ['Asset Tag', 'Serial', 'Asset Name'])
  end

  # Return a table of in-warranty laptops.
  def print_laptops_in_warranty(fleet_type)
    laptops = get_laptops(fleet_type)
    data = laptops.reject{|i| i['warranty_expires'].nil? or Date.parse(i['warranty_expires']['date']) < DateTime.now}
      .sort_by{|i| i['warranty_expires']['date']}
      .map{|i| [i['warranty_expires']['date'], i['asset_tag'], i['serial'], i['name']]}
    print_table(data, ['Warranty Expires', 'Asset Tag', 'Serial', 'Asset Name'])
  end

  # Return a table of laptops sorted by age.
  # Age is approximate. This method does not calculate the intricacies of leap years, etc.
  # @param [Float] older_than_years Filter out results that are newer than the approx years given
  def print_laptops_by_age(fleet_type, older_than_years = 0.0)
    laptops = get_laptops(fleet_type)
    data = []

    # Do not include these very old assets if filtering by age
    if older_than_years == 0.0
      # Format assets that have word based asset_tags, such as 'oldspare03'
      data += laptops.reject{|i| i['asset_tag'].to_i != 0}
        .sort_by{|i| i['asset_tag']}
        .map{|i| ['---', '---', i['asset_tag'], i['serial'], i['name']]}

      # Format assets that are so old the asset_tags increment from '000000001' and up
      data += laptops.reject{|i| i['asset_tag'].to_i == 0 or i['asset_tag'].to_i > 100}
        .sort_by{|i| i['asset_tag']}
        .map{|i| ['---', '---', i['asset_tag'], i['serial'], i['name']]}
    end

    # Format assets that have date-based asset_tags (default asset_tag structure)
    date_asset_tags = laptops.reject{|i| i['asset_tag'].to_i == 0 or i['asset_tag'].to_i <= 100}

    # Filter date-based asset_tags based on approx age
    if older_than_years != 0.0
      date_asset_tags = date_asset_tags.reject{|i| calculate_asset_age(i) < older_than_years}
    end

    data += date_asset_tags.sort_by{|i| i['asset_tag']}
      .map{|i| [Date.parse(i['asset_tag']).strftime('%Y-%m-%d'), calculate_asset_age(i), i['asset_tag'], i['serial'], i['name']]}

    print_table(data, ['Purchase Date', 'Approx Age', 'Asset Tag', 'Serial', 'Asset Name'])
  end

  def print_laptops_by_status(fleet_type, status = nil, type = false)
    laptops = get_laptops(fleet_type)
    status_field = type ? 'status_type' : 'name'
    if not status.nil?
      laptops = laptops.reject{|i| i['status_label'][status_field] != status}
    end
    data = laptops.sort_by{|i| i['status_label'][status_field]}
        .map{|i| [i['status_label'][status_field], i['asset_tag'], i['serial'], i['name']]}
    print_table(data, ['Status', 'Asset Tag', 'Serial', 'Asset Name'])
  end

  def print_laptop_sale_price(asset_tag)
    laptop = get_laptop(asset_tag)
    age = calculate_asset_age(laptop)
    price = nil
    if not laptop['purchase_cost'].nil? and not age.nil?
      price = laptop['purchase_cost'].to_i * (1 - [age, DEPRECIATION_PERIOD].min/DEPRECIATION_PERIOD)
    end
    print_table([[price, age, laptop['purchase_cost'], laptop['asset_tag'], laptop['serial'], laptop['name']]],
      ['Est Price', 'Approx Age', 'Purchase Cost', 'Asset Tag', 'Serial', 'Asset Name'])
  end

  def print_laptop_info(asset_tag)
    ignored_fields = ['available_actions', 'category', 'checkin_counter', 'checkout_counter', 'company', 'created_at', 'custom_fields', 'deleted_at', 'eol', 'expected_checkin', 'image', 'last_audit_date', 'location', 'last_checkout', 'model_number', 'next_audit_date', 'requests_counter', 'rtd_location', 'supplier', 'updated_at', 'warranty_months']
    name_fields = ['model', 'status_label', 'manufacturer']
    date_fields = ['updated_at', 'warranty_expires', 'purchase_date']

    laptop = get_laptop(asset_tag)
    laptop = laptop.reject{|k,v| ignored_fields.include?(k)}
    data = []
    laptop.each do |k,v|
      case k
      when *name_fields
        data << [k, v['name']]
      when *date_fields
        data << [k, v['formatted']]
      when 'assigned_to'
        unless v.nil?
          data << [k, v['username']]
        end
      else
        data << [k, v]
      end
    end

    print_table(data, ['Attribute', 'Value'])
    print_laptop_url(laptop['id'])
  end

  # --------------------------------------------------------
  # Status Queries
  # --------------------------------------------------------

  def print_statuses
    response = self.query('statuslabels')
    data = response['rows'].sort_by{|i| i['type']}
      .map{|i| [i['id'], i['type'], i['name']]}
    print_table(data, ['ID', 'Type', 'Name'])
  end

  # --------------------------------------------------------
  # Model Queries
  # --------------------------------------------------------

  def get_models
    response = self.query('models')
    data = response['rows'].reject{|i| i['category']['name'] != 'Laptop'}
      .sort_by{|i|i['manufacturer']['name']}
      .map{|i| [i['id'], i['name'], i['manufacturer']['name'], i['assets_count']]}
    print_table(data)
  end

  def get_manufacturers
    response = self.query('manufacturers')
    data = response['rows'].sort_by{|i| i['id']}
      .map{|i| [i['id'], i['name'], i['assets_count']]}
    print_table(data)
  end

  # --------------------------------------------------------
  # User Queries
  # --------------------------------------------------------

  def print_all_users
    users = get_users
    data = users.sort_by{|i| i['username']}
      .map{|i| [i['id'], i['username']]}
      print_table(data, ['ID', 'Username'])
  end

  def print_mac_users
  end

  def print_linux_users
  end

  def print_users_with_no_assets
  end

  def print_users_with_multiple_assets
  end

end

