require "spec_helper"
require "openssl"

RSpec.describe Heleket::Webhook do
  let(:secret_key) { "supersecret" }

  let(:valid_payload) do
    {
      "type" => "payment",
      "uuid" => "abc-123",
      "order_id" => "order-456",
      "amount" => "100.00",
      "payment_amount" => "100.00",
      "payment_amount_usd" => "10.00",
      "merchant_amount" => "98.00",
      "commission" => "2.00",
      "is_final" => true,
      "status" => "paid",
      "from" => "wallet-address",
      "wallet_address_uuid" => nil,
      "network" => "tron",
      "currency" => "TRX",
      "payer_currency" => "TRX",
      "additional_data" => "notes",
      "convert" => {
        "to_currency" => "USDT",
        "commission" => "0.1",
        "rate" => "1.00",
        "amount" => "98.00"
      },
      "txid" => "tx-789"
    }
  end

  def with_signature(payload)
    body = payload.dup
    sign = OpenSSL::HMAC.hexdigest("MD5", secret_key, body.to_s)
    body.merge("sign" => sign)
  end

  describe ".parse" do
    it "parses valid payload with convert" do
      parsed = described_class.parse(with_signature(valid_payload), secret_key)

      expect(parsed).to be_a(Heleket::Webhook::Payload)
      expect(parsed.status).to eq("paid")
      expect(parsed.convert).to be_a(Heleket::Webhook::Convert)
      expect(parsed.convert.to_currency).to eq("USDT")
    end

    it "parses valid payload without convert" do
      payload = valid_payload.except("convert")
      parsed = described_class.parse(with_signature(payload), secret_key)

      expect(parsed.convert).to be_nil
    end

    it "raises if signature is invalid" do
      payload = valid_payload.merge("sign" => "invalid-sign")

      expect {
        described_class.parse(payload, secret_key)
      }.to raise_error(Heleket::InvalidHashError)
    end
  end
end
