# frozen_string_literal: true

class TestExpo < Verse::Exposition::Base
  # Include the JSON-RPC extension
  include Verse::JsonRpc::Exposition::Extension

  # Define the HTTP path for the JSON-RPC endpoint
  json_rpc http_path: "rpc", batch_limit: 5

  expose json_rpc_method do
    input do
      field(:message, String)
    end
    output do
      field(:echo_message, String)
    end
  end
  def echo
    # This method is not used in the JSON-RPC context
    # It's just here to demonstrate the structure
    { echo_message: "Echo: #{params[:message]}" }
  end

  expose json_rpc_method do
    desc "A method that always raises an error"
  end
  def raise_error
    raise "This is a test error"
  end
end

class TestExpoStopOnError < Verse::Exposition::Base
  # Include the JSON-RPC extension
  include Verse::JsonRpc::Exposition::Extension

  # Define the HTTP path for the JSON-RPC endpoint
  json_rpc http_path: "rpc_stop", batch_limit: 5, batch_failure: :stop

  expose json_rpc_method do
    input do
      field(:message, String)
    end
    output do
      field(:echo_message, String)
    end
  end
  def echo
    { echo_message: "Echo: #{params[:message]}" }
  end

  expose json_rpc_method do
    desc "A method that always raises an error"
  end
  def raise_error
    raise "This is a test error"
  end
end
