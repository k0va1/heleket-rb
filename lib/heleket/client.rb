require "faraday"
require "openssl"
require "base64"

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

    def handle_errors!(response)
      body = response.body

      case response.status
      when 500..599
        raise Error::ServerError.new(response.status, body["message"])
      end

      nil if body["state"] == 0
    end

    PaymentResponse = Data.define(:uuid, :order_id, :amount, :payment_amount, :payer_amount,
      :discount_percent, :discount, :payer_currency, :currency, :merchant_amount, :network,
      :address, :from, :txid, :payment_status, :url, :expired_at, :is_final, :additional_data,
      :created_at, :updated_at)
    def create_payment(amount:, currency:, order_id:, **params)
      response = @conn.post("v1/payment", {
        amount: amount,
        currency: currency,
        order_id: order_id,
        **params
      }.compact)

      handle_errors!(response)

      PaymentResponse.new(**response.body["result"].transform_keys(&:to_sym))
    end

    def payment_info(uuid:, order_id:)
      response = @conn.post("v1/payment/info", {uuid: uuid, order_id: order_id})

      handle_errors!(response)

      PaymentResponse.new(**response.body["result"].transform_keys(&:to_sym))
    end

    Limit = Data.define(:min_amount, :max_amount)
    Commission = Data.define(:fee_amount, :percent)
    PaymentService = Data.define(:network, :currency, :is_available, :limit, :commission)
    def payment_services
      response = @conn.post("v1/payment/services")

      handle_errors!(response)

      response.body["result"].map do |item|
        limit = Limit.new(**item["limit"].transform_keys(&:to_sym))
        commission = Commission.new(**item["commission"].transform_keys(&:to_sym))
        PaymentService.new(
          **item.transform_keys(&:to_sym),
          limit: limit,
          commission: commission
        )
      end
    end

    QrCode = Data.define(:image)
    def payment_qr(merchant_payment_uuid:)
      response = @conn.post("v1/payment/qr", {merchant_payment_uuid: uuid})

      handle_errors!(response)

      QrCode.new(**response.body["result"].transform_keys(&:to_sym))
    end

    ExchangeRate = Data.define(:from, :to, :course)
    def get_exchange_rate(currency)
      response = @conn.get("v1/exchange_rate/#{currency}/list")

      handle_errors!(response)

      response.body["result"].map do |item|
        ExchangeRate.new(**item.transform_keys(&:to_sym))
      end
    end

    class SignRequestMiddleware < Faraday::Middleware
      def initialize(app, secret_key)
        super(app)
        @secret_key = secret_key
      end

      def call(env)
        signature = OpenSSL::HMAC.hexdigest("MD5", @secret_key, env.body.to_s)
        env.request_headers["sign"] = signature

        @app.call(env)
      end
    end
  end
end
