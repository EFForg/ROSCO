load './snipe.rb'
load './table_printer.rb'

class SnipeQuery
  DEPRECIATION_IN_YEARS = 4.0
  BASE_URL = 'https://snipeit.app.eff.org/'
  API_URL = "#{ BASE_URL }api/v1/"

  def initialize
    @snipe = Snipe.new(API_URL)
    @printer = TablePrinter.new(BASE_URL)
  end

  # --------------------------------------------------------
  # Helpers
  # --------------------------------------------------------

  def asset_tag_type(asset_tag)
    case asset_tag.to_i
    when asset_tag == 0
      'word-based'
    when asset_tag < 100
      'incremental'
    else
      'date-based'
    end
  end

  def calculate_asset_age(asset_tag)
    # Return nil if the asset has a non-date-based asset_tag
    if asset_tag_type(asset_tag) != 'date-based'
      return nil
    else
      return ((Date.today - Date.parse(asset_tag))/365.0).round(3)
    end
  end

  def hash_value(maybe_hash, value)
    maybe_hash.is_a?(Hash) ? maybe_hash[value] : nil
  end

  def find_value(a_hash, nested_keys)
    keys = nested_keys.split('.')
    value = a_hash
    while keys.count > 0
      if value.nil?
        break
      else
        value = value[keys.first] unless value.nil?
        keys.shift
      end
    end

    if value.is_a?(Hash)
      nil
    elsif value.is_a?(Array)
      value.join(', ')
    else
      value
    end
  end

  def print_simple(set, subset_keys, sort = nil, headings = [], title = nil)
    set = set.sort_by {|i| find_value(i, sort) } unless sort.nil?
    subset = set.map do |i|
      res = []
      subset_keys.each {|j| res << find_value(i, j) }
      res
    end
    @printer.print_table(subset, headings, title)
  end

  # --------------------------------------------------------
  # Laptops
  #
  # fleet_type Can be: :all, :spares, :staff, :archived
  # --------------------------------------------------------

  # Return a table of in-warranty laptops.
  def print_laptops(fleet_type)
    print_simple(@snipe.laptops(fleet_type), %w(asset_tag serial name assigned_to.username), 'asset_tag', ['Asset Tag', 'Serial', 'Asset Name', 'Assigned To'])
  end

  # Return a table of in-warranty laptops.
  def print_laptops_in_warranty(fleet_type)
    laptops = @snipe.laptops(fleet_type)
    data = laptops.reject {|i| i['in_warranty'] == false }
    print_simple(data, %w(warranty_expires.formatted asset_tag serial name assigned_to.username), 'warranty_expires.formatted', ['Warranty Expires', 'Asset Tag', 'Serial', 'Asset Name', 'Assigned To'])
  end

  # Return a table of laptops sorted by age.
  # Age is approximate. This method does not calculate the intricacies of leap years, etc.
  #
  # @param [Float] older_than_years Filter out results that are newer than the approx years given
  # @todo Refactor
  def print_laptops_by_age(fleet_type, older_than_years = 0.0)
    laptops = @snipe.laptops(fleet_type)
    data = []

    # Do not include these very old assets if filtering by age
    if older_than_years == 0.0
      # Format assets that have word based asset_tags, such as 'oldspare03'
      data += laptops.reject {|i| asset_tag_type(i['asset_tag']) != 'word-based' }
        .sort_by {|i| i['asset_tag'] }
        .map {|i| ['---', '---', i['asset_tag'], i['serial'], i['name']] }

      # Format assets that are so old the asset_tags increment from '000000001' and up
      data += laptops.reject {|i| asset_tag_type(i['asset_tag']) != 'incremental' }
        .sort_by {|i| i['asset_tag'] }
        .map {|i| ['---', '---', i['asset_tag'], i['serial'], i['name']] }
    end

    # Format assets that have date-based asset_tags (default asset_tag structure)
    date_asset_tags = laptops.reject {|i| asset_tag_type(i['asset_tag']) != 'date-based' }

    # Filter date-based asset_tags based on approx age
    if older_than_years != 0.0
      date_asset_tags = date_asset_tags.reject {|i| calculate_asset_age(i['asset_tag']) < older_than_years }
    end

    data += date_asset_tags.sort_by {|i| i['asset_tag'] }
      .map {|i| [Date.parse(i['asset_tag']).strftime('%Y-%m-%d'), calculate_asset_age(i['asset_tag']), i['asset_tag'], i['serial'], i['name']] }

    @printer.print_table(data, ['Purchase Date', 'Approx Age', 'Asset Tag', 'Serial', 'Asset Name'])
  end

  def print_laptops_by_status(fleet_type, status = nil, type = false)
    laptops = @snipe.laptops(fleet_type)
    status_field = type ? 'status_type' : 'name'
    laptops = laptops.reject {|i| i['status_label'][status_field] != status } unless status.nil?
    status_element = 'status_label.' + status_field
    print_simple(laptops, [status_element, 'asset_tag', 'serial', 'name', 'assigned_to.username'], status_element, ['Status', 'Asset Tag', 'Serial', 'Asset Name', 'Assigned To'])
  end

  def print_laptop_sale_price(asset_tag)
    laptop = @snipe.get_laptop(asset_tag)
    age = calculate_asset_age(asset_tag)
    price = nil
    if not laptop['purchase_cost'].nil? and not age.nil?
      price = laptop['purchase_cost'].to_i * (1 - [age, DEPRECIATION_IN_YEARS].min/DEPRECIATION_IN_YEARS)
    end
    @printer.print_table([[price, age, laptop['purchase_cost'], laptop['asset_tag'], laptop['serial'], laptop['name']]],
      ['Est Price', 'Approx Age', 'Purchase Cost', 'Asset Tag', 'Serial', 'Asset Name'])
  end

  def print_laptop_info(asset_tag)
    ignored_fields = ['available_actions', 'category', 'checkin_counter', 'checkout_counter', 'company', 'created_at', 'custom_fields', 'deleted_at', 'eol', 'expected_checkin', 'image', 'last_audit_date', 'location', 'last_checkout', 'model_number', 'next_audit_date', 'requests_counter', 'rtd_location', 'supplier', 'updated_at', 'warranty_months']
    name_fields = ['model', 'status_label', 'manufacturer']
    date_fields = ['updated_at', 'warranty_expires', 'purchase_date']

    laptop = @snipe.get_laptop(asset_tag).reject {|k,v| ignored_fields.include?(k) }
    data = []
    laptop.each do |k,v|
      case k
      when *name_fields
        data << [k, hash_value(v, 'name')]
      when *date_fields
        data << [k, hash_value(v, 'formatted')]
      when 'assigned_to'
        unless v.nil?
          data << [k, hash_value(v, 'username')]
        end
      else
        data << [k, v]
      end
    end

    @printer.print_table(data, ['Attribute', 'Value'])
    @printer.print_laptop_url(laptop['id'])
  end

  # --------------------------------------------------------
  # Statuses
  # --------------------------------------------------------

  def print_statuses
    print_simple(@snipe.statuses, %w(id type name), 'type', %w(ID Type Name))
  end

  # --------------------------------------------------------
  # Models
  # --------------------------------------------------------

  def print_models
    print_simple(@snipe.models, %w(id name manufacturer.name assets_count), 'manufacturer.name', %w(ID Name Manufacturer Num_Assets))
  end

  def print_laptop_models
    print_simple(@snipe.laptop_models, %w(id name manufacturer.name assets_count), 'manufacturer.name', %w(ID Name Manufacturer Num_Assets))
  end

  def print_manufacturers
    print_simple(@snipe.manufacturers, %w(id name assets_count), 'name', %w(ID Name Num_Assets))
  end

  # --------------------------------------------------------
  # Users
  # --------------------------------------------------------

  def print_users
    print_simple(@snipe.users, %w(id username laptops), 'username', %w(ID Username Laptops))
  end

  def print_laptops_by_manufacturer(fleet_type)
    laptop_manufacturers = @snipe.laptop_manufacturers
    laptops = @snipe.laptops(fleet_type)
    laptop_manufacturers.each do |i|
      set = laptops.reject {|j| j['manufacturer']['name'] != i }
      print_simple(set, %w(asset_tag serial name assigned_to.username), 'asset_tag', ['Asset Tag', 'Serial', 'Asset Name', 'Assigned To'], i) unless set.empty?
    end
  end

  def print_mac_users
  end

  def print_linux_users
  end

  def print_users_with_no_assets
    set = @snipe.users.reject {|i| not i['laptops'].nil? }
    print_simple(set, %w(id username laptops), 'username', %w(ID Username Laptops))
  end

  def print_users_with_multiple_assets
    set = @snipe.users.reject {|i| i['laptops'].nil? or i['laptops'].count < 2 }
    print_simple(set, %w(id username laptops), 'username', %w(ID Username Laptops))
  end
end
