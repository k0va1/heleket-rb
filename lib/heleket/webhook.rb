module Heleket
  module Webhook
    def self.parse(payload, secret_key)
      check_signature!(payload, secret_key)

      hash = payload.transform_keys(&:to_sym)
      convert_hash = hash[:convert]
      convert = if convert_hash
        Webhook::Convert.new(**convert_hash.transform_keys(&:to_sym))
      end

      Webhook::Payload.new(**hash.merge(convert: convert))
    end

    def self.check_signature!(payload, secret_key)
      sign = payload.delete("sign")
      expected_sign = OpenSSL::HMAC.hexdigest("MD5", secret_key, payload.to_s)

      raise ::Heleket::InvalidHashError unless sign == expected_sign
    end

    Convert = Data.define(
      :to_currency,
      :commission,
      :rate,
      :amount
    )

    Payload = Data.define(
      :type,
      :uuid,
      :order_id,
      :amount,
      :payment_amount,
      :payment_amount_usd,
      :merchant_amount,
      :commission,
      :is_final,
      :status,
      :from,
      :wallet_address_uuid,
      :network,
      :currency,
      :payer_currency,
      :additional_data,
      :convert,
      :txid
    )
  end
end
