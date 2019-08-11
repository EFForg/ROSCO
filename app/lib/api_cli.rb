require 'tty-prompt'

class APICLI
  def initialize(query)
    @query = query
    @prompt = TTY::Prompt.new
    @commands = @query.commands
  end

  def run
    type = @prompt.select("What do you want to query?", @commands.keys + ['Exit'])
    exit if type == 'Exit'
    command = @prompt.select("Which #{ type.downcase } query?", @commands[type])
    params = @query.command_params(command)
    if params.empty?
      @query.send(command)
    else
      args = []
      params.each do |param|
        args << ask_param(param)
      end
      @query.send(command, *args)
    end
    # Keep going until the user chooses to exit
    run
  end

  def ask_param(param)
    prefix = param.include?(:req) ? '(Required)' : '(Optional)'
    param_name = param[1]
    guidance = ''
    guidance = param[2] if param.count > 2 and param[2].is_a?(String)
    question = [prefix, param_name, guidance].join(' ')
    if param.count == 4
      @prompt.select(question, param[3])
    else
      @prompt.ask(question)
    end
  end
end
