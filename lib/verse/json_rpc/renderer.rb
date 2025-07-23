# frozen_string_literal: true

require "json"
require_relative "./errors"

module Verse
  module JsonRpc
    class Renderer
      ERROR_CODES = {
        ParseError => 400,

        InvalidRequestError => 400,
        MethodNotFoundError => 404,
        InvalidParamsError => 400,

        InternalError => 500,
        ServerError => 500
      }.freeze

      def render_error(error, ctx)
        ctx.content_type("application/json")
        ctx.response.status = ERROR_CODES.fetch(error.class, 500)

        case error
        when Verse::Error::Authorization
          ctx.response.status = 401
          AuthenticationError.new.to_json
        when Verse::Error::ValidationFailed
          ctx.response.status = 422
          InvalidParamsError.new(message: error.message).to_json
        when Verse::JsonRpc::Error
          ctx.response.status = 400
          error.to_json
        else
          # :nocov:
          # This is a fallback for unexpected errors
          ctx.response.status = 500
          if error.respond_to?(:message)
            InternalError.new(message: error.message).to_json
          else
            InternalError.new.to_json
          end
          # :nocov:
        end
      end

      def render(result, ctx)
        ctx.content_type("application/json")

        if result.nil? || result.is_a?(Array) && result.empty?
          ctx.response.status = 204
          return
        end

        ctx.response.status = 200
        result.to_json
      end
    end
  end
end
