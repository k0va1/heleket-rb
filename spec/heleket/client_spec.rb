require "spec_helper"
require "heleket/client"

RSpec.describe Heleket::Client do
  let(:api_key) { "test_key" }
  let(:merchant_id) { "8b03432e-385b-4670-8d06-064591096795" }
  let(:client) { described_class.new(api_key: api_key, merchant_id: merchant_id) }

  let(:payment_params) do
    {
      amount: "15",
      currency: "USD",
      order_id: "1"
    }
  end

  let(:response_body) do
    {
      state: 0,
      result: {
        uuid: "26109ba0-b05b-4ee0-93d1-fd62c822ce95",
        order_id: "1",
        amount: "15.00",
        payment_amount: nil,
        payer_amount: nil,
        discount_percent: nil,
        discount: "0.00000000",
        payer_currency: nil,
        currency: "USD",
        merchant_amount: nil,
        network: nil,
        address: nil,
        from: nil,
        txid: nil,
        payment_status: "check",
        url: "https://pay.heleket.com/pay/26109ba0-b05b-4ee0-93d1-fd62c822ce95",
        expired_at: 1_689_098_133,
        is_final: false,
        additional_data: nil,
        created_at: "2023-07-11T20:23:52+03:00",
        updated_at: "2023-07-11T21:24:17+03:00"
      }
    }
  end

  before do
    stub_request(:post, "https://api.heleket.com/v1/payment")
      .with(
        body: payment_params.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      ).to_return(
        status: 200,
        body: response_body.to_json,
        headers: {"Content-Type" => "application/json"}
      )
  end

  describe "#create_payment" do
    it "creates a payment and returns a PaymentResponse object" do
      response = client.create_payment(**payment_params)

      expect(response).to be_a(Heleket::Client::PaymentResponse)
      expect(response.uuid).to eq("26109ba0-b05b-4ee0-93d1-fd62c822ce95")
      expect(response.amount).to eq("15.00")
      expect(response.currency).to eq("USD")
      expect(response.payment_status).to eq("check")
      expect(response.url).to include("heleket.com/pay/")
    end
  end

  describe "#get_exchange_rate" do
    let(:currency) { "USD" }
    let(:url) { "https://api.heleket.com/v1/exchange_rate/#{currency}/list" }

    context "when the response is successful" do
      let(:response_body) {
        {
          "state" => 0,
          "result" => [
            {"from" => "USD", "to" => "USDT", "course" => "1.00"},
            {"from" => "USD", "to" => "BTC", "course" => "0.000025"}
          ]
        }
      }

      before do
        stub_request(:get, url)
          .to_return(status: 200, body: response_body.to_json, headers: {"Content-Type" => "application/json"})
      end

      it "returns an array of ExchangeRate objects" do
        rates = client.get_exchange_rate(currency)

        expect(rates).to all(be_a(Heleket::Client::ExchangeRate))
        expect(rates.map(&:to)).to contain_exactly("USDT", "BTC")
        expect(rates.first.course).to eq("1.00")
      end
    end
  end

  describe "#payment_services" do
    let(:response_body) do
      {
        state: 0,
        result: [
          {
            network: "ETH",
            currency: "USDT",
            is_available: true,
            limit: {
              min_amount: "1.0",
              max_amount: "10000.0"
            },
            commission: {
              fee_amount: "0.00",
              percent: "2.00"
            }
          }
        ]
      }
    end

    before do
      stub_request(:post, "https://api.heleket.com/v1/payment/services")
        .to_return(status: 200, body: response_body.to_json, headers: {"Content-Type" => "application/json"})
    end

    it "returns parsed payment services" do
      result = client.payment_services

      expect(result).to be_an(Array)
      expect(result.first.network).to eq("ETH")
      expect(result.first.currency).to eq("USDT")
      expect(result.first.is_available).to eq(true)
      expect(result.first.limit.min_amount).to eq("1.0")
      expect(result.first.commission.percent).to eq("2.00")
    end
  end
end
