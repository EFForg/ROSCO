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

  # --------------------------------------------------------
  # Laptops
  #
  # fleet_type Can be: 'all', 'spares', 'staff', 'archived'
  # --------------------------------------------------------

  # Return a table of in-warranty laptops.
  def print_laptops(fleet_type)
    laptops = @snipe.get_laptops(fleet_type)
    data = laptops.sort_by{|i| i['asset_tag']}
      .map{|i| [i['asset_tag'], i['serial'], i['name']]}
    @printer.print_table(data, ['Asset Tag', 'Serial', 'Asset Name'])
  end

  # Return a table of in-warranty laptops.
  def print_laptops_in_warranty(fleet_type)
    laptops = @snipe.get_laptops(fleet_type)
    data = laptops.reject{|i| i['warranty_expires'].nil? or Date.parse(i['warranty_expires']['date']) < DateTime.now}
      .sort_by{|i| i['warranty_expires']['date']}
      .map{|i| [i['warranty_expires']['date'], i['asset_tag'], i['serial'], i['name']]}
    @printer.print_table(data, ['Warranty Expires', 'Asset Tag', 'Serial', 'Asset Name'])
  end

  # Return a table of laptops sorted by age.
  # Age is approximate. This method does not calculate the intricacies of leap years, etc.
  # @param [Float] older_than_years Filter out results that are newer than the approx years given
  def print_laptops_by_age(fleet_type, older_than_years = 0.0)
    laptops = @snipe.get_laptops(fleet_type)
    data = []

    # Do not include these very old assets if filtering by age
    if older_than_years == 0.0
      # Format assets that have word based asset_tags, such as 'oldspare03'
      data += laptops.reject{|i| asset_tag_type(i['asset_tag']) != 'word-based'}
        .sort_by{|i| i['asset_tag']}
        .map{|i| ['---', '---', i['asset_tag'], i['serial'], i['name']]}

      # Format assets that are so old the asset_tags increment from '000000001' and up
      data += laptops.reject{|i| asset_tag_type(i['asset_tag']) != 'incremental'}
        .sort_by{|i| i['asset_tag']}
        .map{|i| ['---', '---', i['asset_tag'], i['serial'], i['name']]}
    end

    # Format assets that have date-based asset_tags (default asset_tag structure)
    date_asset_tags = laptops.reject{|i| asset_tag_type(i['asset_tag']) != 'date-based'}

    # Filter date-based asset_tags based on approx age
    if older_than_years != 0.0
      date_asset_tags = date_asset_tags.reject{|i| calculate_asset_age(i['asset_tag']) < older_than_years}
    end

    data += date_asset_tags.sort_by{|i| i['asset_tag']}
      .map{|i| [Date.parse(i['asset_tag']).strftime('%Y-%m-%d'), calculate_asset_age(i['asset_tag']), i['asset_tag'], i['serial'], i['name']]}

    @printer.print_table(data, ['Purchase Date', 'Approx Age', 'Asset Tag', 'Serial', 'Asset Name'])
  end

  def print_laptops_by_status(fleet_type, status = nil, type = false)
    laptops = @snipe.get_laptops(fleet_type)
    status_field = type ? 'status_type' : 'name'
    if not status.nil?
      laptops = laptops.reject{|i| i['status_label'][status_field] != status}
    end
    data = laptops.sort_by{|i| i['status_label'][status_field]}
      .map{|i| [i['status_label'][status_field], i['asset_tag'], i['serial'], i['name']]}
    @printer.print_table(data, ['Status', 'Asset Tag', 'Serial', 'Asset Name'])
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

    laptop = @snipe.get_laptop(asset_tag).reject{|k,v| ignored_fields.include?(k)}
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

    @printer.print_table(data, ['Attribute', 'Value'])
    @printer.print_laptop_url(laptop['id'])
  end

  # --------------------------------------------------------
  # Statuses
  # --------------------------------------------------------

  def print_statuses
    statuses = @snipe.get_statuses
    data = statuses.sort_by{|i| i['type']}
      .map{|i| [i['id'], i['type'], i['name']]}
    @printer.print_table(data, ['ID', 'Type', 'Name'])
  end

  # --------------------------------------------------------
  # Models
  # --------------------------------------------------------

  def print_models
    models = @snipe.get_models
    data = models.reject{|i| i['category']['name'] != 'Laptop'}
      .sort_by{|i|i['manufacturer']['name']}
      .map{|i| [i['id'], i['name'], i['manufacturer']['name'], i['assets_count']]}
    @printer.print_table(data)
  end

  def print_manufacturers
    manufacturers = @snipe.get_manufacturers
    data = manufacturers.sort_by{|i| i['id']}
      .map{|i| [i['id'], i['name'], i['assets_count']]}
    @printer.print_table(data)
  end

  # --------------------------------------------------------
  # Users
  # --------------------------------------------------------

  def print_users
    users = @snipe.get_users
    data = users.sort_by{|i| i['username']}
      .map{|i| [i['id'], i['username']]}
    @printer.print_table(data, ['ID', 'Username'])
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
