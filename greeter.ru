# frozen_string_literal: true

# SPDX-License-Identifier: Apache-2.0

require "action_controller/railtie"

# Greeter is a minimal Rails application inspired by
# the Rails bug report template for action controller.
# The configuration is compatible with Rails 6.0
class GreeterApp < Rails::Application
  config.root = __dir__
  config.hosts << 'example.org'
  secrets.secret_key_base = 'secret_key_base'
  config.eager_load = false
  config.logger = Logger.new($stdout)
  Rails.logger  = config.logger

  routes.append do
    get "/greeting" => "greetings#index"
    get "/error" => "errors#index" # Errors as a Service
    get '/health', to: ->(env) { [204, {}, ['']] }
  end
end

class GreetingsController < ActionController::Base
  # GET /greeting?name=Eustace
  def index
    @name = params.fetch(:name, "honored visitor")
    render inline: "Hello, <%= @name %>.\n"
  end
end

class ErrorsController < ActionController::Base
  # GET /error -> always 500s as a result of an exception in the view template
  def index
    render inline: <<~ERROR_PRONE_ERB
      You won't see this sentence render in the response.
      Because I'm gonna <% raise 'an exception inside ActionView!' %>
    ERROR_PRONE_ERB
  end
end

Rails.application.initialize!

Rack::Server.new(app: GreeterApp, Port: 3000).start

# To run this example run the `rackup` command with this file
# Example: rackup greeter.ru
# Navigate to http://localhost:3000/
