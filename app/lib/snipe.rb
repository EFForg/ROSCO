require 'httparty'

class Snipe
  LAPTOP_CATEGORY_ID = 1
  API_KEY_PATH = '/secrets/api_key.txt'

  def initialize(api_url)
    @api_url = api_url
    load_key
  end

  def error(message)
    raise "ERROR: #{message}"
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
  def get_active_laptops
    if @active_laptops.nil?
      response = query('hardware', {'category_id' => LAPTOP_CATEGORY_ID})
      @active_laptops = response['rows']
    else
      @active_laptops
    end
  end

  # Return all non-archived spare laptops
  def get_spare_laptops
    if @spare_laptops.nil?
      response = query('hardware', {'category_id' => LAPTOP_CATEGORY_ID, 'status' => 'Requestable'})
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
      response = query('hardware', {'category_id' => LAPTOP_CATEGORY_ID, 'status' => 'Archived'})
      @archived_laptops = response['rows']
    else
      @archived_laptops
    end
  end

  def get_laptops(type)
    if type == 'spares'
      return get_spare_laptops
    elsif type == 'staff'
      return get_staff_laptops
    elsif type == 'archived'
      return get_archived_laptops
    else
      return get_active_laptops
    end
  end

  # Get one laptop by asset_tag
  def get_laptop(asset_tag)
    query("hardware/bytag/#{asset_tag}")
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

  def get_manufacturers
    if @manufacturers.nil?
      response = self.query('manufacturers')
      @manufacturers = response['rows']
    else
      @manufacturers
    end
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
