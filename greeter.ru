# frozen_string_literal: true

# SPDX-License-Identifier: Apache-2.0

require "action_controller/railtie"

require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/all'

module O11yWrapper
  # This span processor reads attributes stored in Baggage in the span's
  # parent context and adds them to the span.
  class BaggageSpanProcessor < OpenTelemetry::SDK::Trace::SpanProcessor
    def on_start(span, parent_context)
      span.add_attributes(OpenTelemetry::Baggage.values(context: parent_context))
    end
  end
end

begin
  OpenTelemetry::SDK.configure do |c|
    c.service_name = ENV['SERVICE_NAME'] || "greeter"
    c.use_all()
    # add the BaggageSpanProcessor to the span pipeline
    c.add_span_processor(O11yWrapper::BaggageSpanProcessor.new)
    # Because we tinkered with the pipeline, we'll need to
    # wire up span batching and sending via OLTP ourselves.
    # This is usually the default.
    c.add_span_processor(
      OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
        OpenTelemetry::Exporter::OTLP::Exporter.new()
      )
    )
  end
rescue OpenTelemetry::SDK::ConfigurationError => e
  puts "Don't like that configuration, friend."
  puts e.inspect
end

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

class ApplicationController < ActionController::Base
  private
  def tracer
    OpenTelemetry.tracer_provider.tracer('greeter-internal')
  end
end

class GreetingsController < ApplicationController
  # GET /greeting?name=Eustace
  def index
    OpenTelemetry::Trace
      .current_span
      .add_event("Emoji are fun! ᕕ( ᐛ )ᕗ")

    @greeting = "Hello"
    @name = params.fetch(:name, "honored visitor")

    OpenTelemetry::Context.with_current(
      OpenTelemetry::Baggage.set_value("app.visitor_name", @name)
    ) do
      tracer.in_span("🎨 render greeting ✨") do |span|
        span.add_attributes({
          "app.greeting" => @greeting
        })
        render inline: "<%= @greeting %>, <%= @name %>."
      end
    end
  end
end

class ErrorsController < ApplicationController
  # GET /error -> always 500s as a result of an exception in the view template
  def index
    OpenTelemetry::Trace
      .current_span
      .add_event("⏲ This action will explode shortly.")

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
