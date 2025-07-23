# frozen_string_literal: true

module Verse
  module JsonRpc
    class Error < StandardError
      attr_reader :id, :code, :message, :data

      def initialize(id: nil, code: nil, message: nil, data: nil)
        @id = id
        @code = code || self.class.code
        @message = message || self.class.message
        @data = data

        super message
      end

      def self.define(code, message, _data = nil)
        Class.new(self) do
          define_singleton_method(:code) { code }
          define_singleton_method(:message) { message }
        end
      end

      def to_h
        out = { code:, message: }

        out[:data] = @data if @data

        {
          jsonrpc: "2.0",
          id: @id,
          error: out
        }
      end

      def to_json(*args)
        to_h.to_json(*args)
      end
    end

    ParseError = Error.define(-32_700, "Parse error")

    InvalidRequestError = Error.define(-32_600, "Invalid request")
    MethodNotFoundError = Error.define(-32_601, "Method not found")
    InvalidParamsError = Error.define(-32_602, "Invalid params")
    InternalError = Error.define(-32_603, "Internal error")

    AuthenticationError = Error.define(-32_001, "Authentication error")
    ServerError = Error.define(-32_000, "Server error")
  end
end
