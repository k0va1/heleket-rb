require "faraday"
require 'openssl'
require 'base64'

module Heleket
  class Client
    API_URL = "https://api.heleket.com"

    attr_reader :api_key, :merchant_id

    def initialize(api_key:, merchant_id:)
      @api_key = api_key
      @merchant_id = merchant_id
      @conn = Faraday.new(url: API_URL) do |faraday|
        faraday.request :json
        faraday.response :json
        faraday.adapter Faraday.default_adapter
      end
    end

    def create_payment(amount:, currency:, order_id:)
      response = @conn.post("v1/payment", {
        amount: amount,
        currency: currency,
        order_id: order_id
      }.compact)
      response
    end

    def payment_info(uuid:, order_id:)
      response = @conn.post("v1/payment/info", {uuid: uuid, order_id: order_id})
      response
    end


    class SignRequestMiddleware < Faraday::Middleware
      def initialize(app, secret_key)
        super(app)
        @secret_key = secret_key
      end

      def call(env)
        signature = OpenSSL::HMAC.hexdigest('MD5', @secret_key, env.body.to_s)
        env.request_headers['sign'] = signature

        @app.call(env)
      end
    end
  end
end
