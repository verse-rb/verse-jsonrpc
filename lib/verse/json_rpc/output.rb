module JsonRpc
  CallResult = Struct.new(:result, :id, keyword_init: true) do
    def to_json
      {
        jsonrpc: "2.0",
        id:,
        result:
      }.to_json
    end
  end

  CallError = Struct.new(:error, :id, keyword_init: true) do
    def to_json
      {
        jsonrpc: "2.0",
        id:,
        error: error.to_h
      }.to_json
    end
  end

end