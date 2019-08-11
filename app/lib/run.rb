require './api_cli.rb'
require './snipe_query.rb'

query = SnipeQuery.new
cli = APICLI.new(query)
cli.run
