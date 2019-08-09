require 'sinatra/base'

# Sync output to STDOUT so docker logs everything.
$stdout.sync = true
$stderr.sync = true

class RubyTest < Sinatra::Application
  # Required so sinatra will listen on not just localhost.
  set :bind, '0.0.0.0'

  # Use port 80.
  set :port, 80

  get '/' do
    echo "In test mode."
  end

  # start the server if ruby file executed directly
  run! if app_file == $0
end
