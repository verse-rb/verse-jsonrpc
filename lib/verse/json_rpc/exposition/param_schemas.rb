# frozen_string_literal: true

module Verse
  module Jsonrpc
    module Exposition
      InputSchema = Verse::Schema.define do
        field(:jsonrpc, String).rule("must be 2.0"){ |v| v == "2.0" }
        field(:method, String).filled
        field?(:params, Object)
        field(:id, [String, Integer, NilClass])
      end

      BatchSchema = Verse::Schema.array(InputSchema)

      AllowedInput = Verse::Schema.scalar(InputSchema, BatchSchema)

      OutputSchema = Verse::Schema.define do
        field(:jsonrpc, String).rule("must be 2.0"){ |v| v == "2.0" }
        field(:id, [String, Integer, NilClass])

        field?(:result, Object)

        field? :error do
          field(:code, Integer)
          field(:message, String)
          field?(:data, Object)
        end

        field?(:result, Object)
      end
    end
  end
end
