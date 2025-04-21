module JsonRpc
  InputSchema = Verse::Schema.define do
    field(:jsonrpc, String).rule("must be 2.0"){ |v| v == "2.0" }
    field(:method, Symbol).filled

    field?(:params, Object)
    field?(:id, [String, Integer])
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
  end
end