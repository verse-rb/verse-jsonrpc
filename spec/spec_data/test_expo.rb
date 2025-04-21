# frozen_string_literal: true

class TestExpo < Verse::Exposition::Base
  # Include the JSON-RPC extension
  include Verse::JsonRpc::Exposition::Extension

  # Define the HTTP path for the JSON-RPC endpoint
  http_path "/rpc"

  # Define JSON-RPC methods within a single block
  json_rpc do
    # Default auth for methods in this block (can be overridden per method)
    # auth :user # Example: Set default auth for the block

    method :echo do
      desc "Echoes back the input parameters"
      input do
        field(:message, String).required
      end
      output do
        field(:echo_message, String)
      end
      call do
        # Access the input parameters via `params` within the call block
        { echo_message: "Echo: #{params[:message]}" }
      end
    end

    method :raise_error do
      desc "A method that always raises an error"
      call do
        raise Verse::Error::ValidationFailed, "This is a test error"
      end
    end

    method :notify_only do
      desc "A method that acts as a notification"
      input do
        field(:data, String).required
      end
      call do
        # Perform some action, but return nothing specific for JSON-RPC
        Verse.logger.info("Notification received: #{params[:data]}")
        nil # Or simply don't return anything meaningful
      end
    end

    method :public_method do
      desc "A public method accessible without authentication"
      input do
        field(:value, Integer).required
      end
      output do
        field(:result, Integer)
      end
      call do
        { result: params[:value] * 2 }
      end
    end
  end # End of json_rpc block

  # Note: The implementation logic is now within the `call` blocks above.
  # No separate `def method_name` needed for methods defined within `json_rpc` block.

end
