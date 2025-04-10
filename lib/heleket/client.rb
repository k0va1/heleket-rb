require "faraday"
require "digest"
require "base64"
require "logger"

module Heleket
  class Client
    API_URL = "https://api.heleket.com"

    attr_reader :api_key, :merchant_id

    def initialize(api_key:, merchant_id:)
      @api_key = api_key
      @merchant_id = merchant_id
      @conn = Faraday.new(url: API_URL) do |faraday|
        faraday.use SignRequestMiddleware, api_key
        faraday.headers["Content-Type"] = "application/json"
        faraday.headers["merchant"] = merchant_id
        faraday.request :json
        faraday.response :json
        faraday.response :logger, ::Logger.new($stdout), bodies: true
        faraday.adapter Faraday.default_adapter
      end
    end

    def handle_errors!(response)
      body = response.body

      case response.status
      when 400..499
        raise ClientError.new(body)
      when 500..599
        raise ServerError.new(response.status, body["message"])
      end
    end

    PaymentResponse = Data.define(:uuid, :order_id, :amount, :payment_amount, :payer_amount,
      :discount_percent, :discount, :payer_currency, :currency, :merchant_amount, :network,
      :address, :from, :txid, :payment_status, :url, :expired_at, :is_final, :additional_data,
      :created_at, :updated_at, :payment_amount_usd, :payer_amount_exchange_rate, :comments, :status, :commission, :address_qr_code)
    def create_payment(amount:, currency:, **params)
      response = @conn.post("v1/payment", {
        amount: amount,
        currency: currency,
        **params
      }.compact)

      handle_errors!(response)

      PaymentResponse.new(**response.body["result"].transform_keys(&:to_sym))
    end

    def payment_info(uuid: nil, order_id: nil)
      raise ArgumentError, "Either uuid or order_id must be provided" if uuid.nil? && order_id.nil?

      response = @conn.post("v1/payment/info", {uuid: uuid, order_id: order_id}.compact)

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
        signature = Digest::MD5.hexdigest(Base64.strict_encode64(env.body.to_json) + @secret_key)
        env.request_headers["sign"] = signature

        @app.call(env)
      end
    end
  end
end
