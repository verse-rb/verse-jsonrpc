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
          # Because verse http will deal with the authorization,
          # we will route
          ctx.response.status = 401
          AuthenticationError.new.to_json
        when  Verse::JsonRpc::Error
          error.to_json
        else
          InternalError.new.to_json
        end
      end

      def render(result, ctx)
        ctx.content_type("application/json")
        ctx.response.status = 200

        output = result.to_json

        ctx.response.status = output.empty? ? 204 : 200

        output
      end
    end
  end
end
