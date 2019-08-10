require 'httparty'

class Snipe
  LAPTOP_CATEGORY_ID = 1
  API_KEY_PATH = '/secrets/api_key.txt'

  def initialize(api_url)
    @api_url = api_url
    load_key
  end

  def error(message)
    raise "ERROR: #{ message }"
  end

  def load_key
    @@access_token ||= begin
      if not File.exist?(API_KEY_PATH)
        error('Missing api key')
      end
      File.read(API_KEY_PATH)
    end
  end

  def query(url, query = {}, offset = 0)
    headers = {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{ @@access_token }",
    }

    query['offset'] = offset if offset > 0
    response = HTTParty.get(@api_url + url, query: query, headers: headers)

    if response.code != 200
      error(__method__.to_s)
    elsif not response.key?('rows')
      return response
    elsif (row_count = response['rows'].count) > 0
      next_response = query(url, query, offset + row_count)
      response['rows'] += next_response['rows'] if next_response.code == 200
    end
    response
  end

  # --------------------------------------------------------
  # Laptops
  # --------------------------------------------------------

  # Return all laptops that are not in the archived Snipe state
  def active_laptops
    @active_laptops ||= query('hardware', { 'category_id' => LAPTOP_CATEGORY_ID })['rows']
  end

  # Return all non-archived spare laptops
  def spare_laptops
    @spare_laptops ||= query('hardware', { 'category_id' => LAPTOP_CATEGORY_ID, 'status' => 'Requestable' })['rows']
  end

  # Return all laptops that are not spares, regardless of current check out status
  def staff_laptops
    @staff_laptops ||= begin
      spare_ids = spare_laptops.map {|i| i['id'] }
      active_laptops.reject {|i| spare_ids.include?(i['id']) }
    end
  end

  # Return all laptops that are in the archived Snipe state
  def archived_laptops
    @archived_laptops ||= query('hardware', { 'category_id' => LAPTOP_CATEGORY_ID, 'status' => 'Archived' })['rows']
  end

  def laptops(type)
    case type
    when 'spares'
      spare_laptops
    when 'staff'
      staff_laptops
    when 'archived'
      archived_laptops
    else
      active_laptops
    end
  end

  # Get one laptop by asset_tag
  def get_laptop(asset_tag)
    query("hardware/bytag/#{ asset_tag }")
  end

  # --------------------------------------------------------
  # Other
  # --------------------------------------------------------

  def get_users
    if @users.nil?
      response = query('users')
      @users = response['rows']
    else
      @users
    end
  end

  def get_models
    if @models.nil?
      response = self.query('models')
      @models = response['rows']
    else
      @models
    end
  end

  def get_laptop_models
    models = get_models
    models.reject{|i| i['category']['name'] != 'Laptop'}
  end

  def get_manufacturers
    if @manufacturers.nil?
      response = self.query('manufacturers')
      @manufacturers = response['rows']
    else
      @manufacturers
    end
  end

  def get_laptop_manufacturers
    models = get_laptop_models
    models.map {|i| i['manufacturer']['name']}.uniq!
  end

  def get_statuses
    if @statuses.nil?
      response = self.query('statuslabels')
      @statuses = response['rows']
    else
      @statuses
    end
  end
end
