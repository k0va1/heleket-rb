# frozen_string_literal: true

require_relative "heleket/version"
require_relative "heleket/client"
require_relative "heleket/webhook"

module Heleket
  class Error < StandardError; end

  class InvalidHashError < Error; end

  class ClientError < Error; end

  class ServerError < Error
    attr_reader :status_code, :response

    def initialize(status_code, response)
      @status_code = status_code
      @response = response
      super("Server error: #{status_code} - #{response}")
    end
  end
end
