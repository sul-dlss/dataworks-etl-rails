# frozen_string_literal: true

# Clients for interacting with external APIs
module Clients
  # Error class for client errors
  class Error < StandardError; end

  # Base class for harvesting clients
  class Base
    attr_reader :url, :conn

    def initialize(url: nil, api_token: nil, conn: nil)
      @url = url
      @api_token = api_token
      @conn = conn || new_conn
    end

    def get_json(path:, params: {})
      conn.get(path, params.compact).body
    rescue Faraday::Error => e
      raise Error, "Connection err: #{e.message}"
    rescue JSON::ParserError => e
      raise Error, "JSON parsing error: #{e.message}"
    end

    private

    attr_reader :api_token

    def new_conn
      Faraday.new({ url: }.compact) do |f|
        f.request :json
        f.request :retry, **retry_options
        f.request :authorization, :Bearer, api_token if api_token
        f.response :json
        f.response :raise_error
      end
    end

    def retry_options
      {
        max: 10,
        interval: 5.0,
        backoff_factor: 2,
        retry_statuses: [429, 502]
      }
    end
  end
end
