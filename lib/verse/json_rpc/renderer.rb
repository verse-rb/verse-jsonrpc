# frozen_string_literal: true

require "json"
require_relative "./errors"

module Verse
  module JsonRpc
    class Renderer
      ERROR_CODES = {
        JsonRpc::ParseError => 400,

        JsonRpc::InvalidRequestError => 400,
        JsonRpc::MethodNotFoundError => 404,
        JsonRpc::InvalidParamsError => 400,

        JsonRpc::InternalError => 500,
        JsonRpc::ServerError => 500
      }.freeze

      def render_error(error, ctx)
        ctx.content_type("application/json")
        ctx.response.status = ERROR_CODES.fetch(error.class, 500)

        case error
        when  Verse::JsonRpc::Error
          error.to_json
        else
          InternalError.new.to_json
        end
      end

      def render(result, ctx)
        ctx.content_type("application/json")

        output = result.to_json

        ctx.response.status = output.empty? ? 204 : 200

        output
      end
    end
  end
end
