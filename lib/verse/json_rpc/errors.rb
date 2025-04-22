module Verse
  module JsonRpc
    class Error < StandardError
      attr_reader :id, :code, :message, :data

      def initialize(id: nil, code: nil, message: nil, data: nil)
        @id = id
        @code = code || self.code
        @message = message || self.message
        @data = data

        super message
      end

      def self.define(code, message, data = nil)
        Class.new(self) do
          define_method(:code) { code }
          define_method(:message) { message }
          define_method(:data) { data }
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

    ParseError = Error.define(-32700, "Parse error")

    InvalidRequestError = Error.define(-32600, "Invalid request")
    MethodNotFoundError = Error.define(-32601, "Method not found")
    InvalidParamsError = Error.define(-32602, "Invalid params")
    InternalError = Error.define(-32603, "Internal error")

    ServerError = Error.define(-32000, "Server error")
  end
end