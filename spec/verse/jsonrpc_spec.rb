# frozen_string_literal: true

require "spec_helper"
require_relative "../spec_data/test_expo"

RSpec.describe Verse::JsonRpc::Exposition::Extension, type: :exposition, as: :system do
  # Include HTTP spec helpers for making requests
  include Verse::Http::Spec::HttpHelper

  # Set up the Verse application context for testing
  before(:all) do
    # Ensure the config path is absolute and correctly resolved
    config_file_path = File.expand_path("../spec_data/config.yml", __dir__)

    Verse.start(
      :test,
      config_path: config_file_path
    )

    # Register the test exposition
    TestExpo.register
  end

  # Helper to build the JSON-RPC request body
  def json_rpc_request(method, params, id = 1)
    { jsonrpc: "2.0", method: method, params: params, id: id }
  end

  # Helper to build a notification request body (no id)
  def json_rpc_notification(method, params)
    { jsonrpc: "2.0", method: method, params: params }
  end

  describe "Single Request Handling" do
    context "when calling the 'echo' method" do
      let(:method) { "echo" }
      let(:params) { { message: "Hello Verse!" } }
      let(:request_id) { 123 }

      it "returns the echoed message with authentication" do
        # Use the authenticated user defined in spec_helper
        post "/rpc", json_rpc_request(method, params, request_id), auth: "user"

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body, symbolize_names: true)
        expect(body).to eq({
          jsonrpc: "2.0",
          result: { echo_message: "Echo: #{params[:message]}" },
          id: request_id
        })
      end

      it "returns an authentication error without credentials" do
        as_user nil do
          post "/rpc", json_rpc_request(method, params, request_id)
        end

        expect(last_response.status).to eq(401)
        body = JSON.parse(last_response.body, symbolize_names: true)
        expect(body).to match(
          jsonrpc: "2.0",
          error: {
            code: Verse::JsonRpc::AuthenticationError.code, # Or the specific code for auth errors
            message: a_kind_of(String) # Check for the presence of an error message
          },
          id: nil # The reason for nil is that the authentication check
                  # is made before the request is processed
        )
      end

      it "returns an error if params are invalid" do
        post "/rpc", json_rpc_request(method, { wrong_param: "foo" }, request_id), auth: "user"

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body, symbolize_names: true)

        expect(body).to match(
          jsonrpc: "2.0",
          error: {
            code: Verse::JsonRpc::InvalidParamsError.code,
            message: "message: is required",
            data: {message: ["is required"]}
          },
          id: request_id
        )

      end
    end

    context "when calling the 'raise_error' method" do
      let(:method) { "raise_error" }
      let(:request_id) { 456 }

      it "returns a JSON-RPC error response" do
        post "/rpc", json_rpc_request(method, {}, request_id) # No params needed, no auth

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body, symbolize_names: true)
        expect(body).to match(
          jsonrpc: "2.0",
          error: {
            code: Verse::JsonRpc::InternalError.code, # Or a more specific code if mapped
            message: "This is a test error",
          },
          id: request_id
        )
      end
    end

    context "when sending a 'notify_only' notification" do
      let(:method) { "echo" }
      let(:params) { { message: "A message" } }

      it "returns an empty response (HTTP 204 or 200 OK)" do
        # Notifications have no 'id'
        post "/rpc", json_rpc_notification(method, params)

        # JSON-RPC notifications should return 204 No Content.
        expect(last_response.status).to eq(204)

        # Expect an empty body for notifications
        expect(last_response.body).to be_empty
      end
    end
  end

  describe "Batch Request Handling" do
    it "handles a batch of valid requests (including success and error)" do
      batch_request = [
        json_rpc_request("echo", { message: "batch echo" }, 1), # ok
        json_rpc_request("echo", { }, 2), # missing required param
        json_rpc_notification("echo", { message: "batch notification" }), # Notification in batch
        json_rpc_request("non_existent_method", {}, 3), # Method not found error
        json_rpc_request("raise_error", {}, 4) # Internal error
      ]

      post "/rpc", batch_request, {"CONTENT_TYPE" => "application/json"} # Send the array as the body

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body, symbolize_names: true)
      expect(body).to be_an(Array)
      expect(body.size).to eq(4) # 4 responses expected (notification doesn't get one)

      # Check responses (order should match request order, excluding notification)
      expect(body).to contain_exactly(
        # Response for echo (id: 1) - Success
        a_hash_including(jsonrpc: "2.0", result: { echo_message: "Echo: batch echo" }, id: 1),
        # Response for echo (id: 2) - Invalid Params
        a_hash_including(
          jsonrpc: "2.0",
          error: a_hash_including(
            code: Verse::JsonRpc::InvalidParamsError.code,
            message: "message: is required",
            data: { message: ["is required"] }
          ),
          id: 2
        ),
        # Response for non_existent_method (id: 3) - Method not found
        a_hash_including(
          jsonrpc: "2.0",
          error: a_hash_including(
            code: Verse::JsonRpc::MethodNotFoundError.code,
            message: "Method not found" # Or a more specific message if generated
          ),
          id: 3
        ),
        # Response for raise_error (id: 4) - Internal error
        a_hash_including(
          jsonrpc: "2.0",
          error: a_hash_including(
            code: Verse::JsonRpc::InternalError.code,
            message: "This is a test error"
          ),
          id: 4
        )
      )
    end

    it "handles an empty batch request array" do
      # Sending an empty array should result in an Invalid Request error from the server/middleware
      post "/rpc", [], { "CONTENT_TYPE" => "application/json" }

      # Expecting 422 Unprocessable Entity as Rack/middleware might handle this before JSON-RPC parsing
      expect(last_response.status).to eq(422)
      # The body might not be a standard JSON-RPC error in this case,
      # depending on how the underlying framework handles empty batch requests.
      # We'll just check the status code for now.
    end

    it "handles a batch containing only notifications" do
      batch_request = [
        json_rpc_notification("notify_only", { data: "notify 1" }),
        json_rpc_notification("notify_only", { data: "notify 2" })
      ]

      # Convert batch to JSON string and set content type
      post "/rpc", batch_request, { "CONTENT_TYPE" => "application/json" }

      # Should return no content as all requests were notifications
      expect([200, 204]).to include(last_response.status) # 204 is preferred, but 200 is acceptable
      expect(last_response.body).to be_empty
    end

    it "returns a single error response if the batch array itself is invalid JSON (handled by Rack/middleware)" do
      # This tests the layer before JSON-RPC parsing
      post "/rpc", "[{\"jsonrpc\": \"2.0\", \"method\": \"echo\", \"params\": {\"message\": \"Valid\"}, \"id\": 1}, InvalidJSON]", { "CONTENT_TYPE" => "application/json" }

      # Expecting 422 Unprocessable Entity as Rack/middleware handles invalid JSON parsing
      expect(last_response.status).to eq(422)
      # Body content might vary depending on the Rack middleware, not necessarily JSON-RPC format.
    end

    it "returns Invalid Request error if batch size exceeds limit" do
      # Create a batch with 6 requests (limit is 5)
      batch_request = 6.times.map do |i|
        json_rpc_request("echo", { message: "test #{i}" }, i + 1)
      end

      post "/rpc", batch_request, { "CONTENT_TYPE" => "application/json" }

      # This is a JSON-RPC level error, so status should be 200
      pp last_response.body
      expect(last_response.status).to eq(400)
      body = JSON.parse(last_response.body, symbolize_names: true)

      expect(body).to match(
        jsonrpc: "2.0",
        error: {
          code: Verse::JsonRpc::InvalidRequestError.code,
          message: "Batch size limit exceeded",
          data: { batch_limit: 5 }
        },
        id: nil # Error applies to the batch structure itself
      )
    end
  end

  describe "Protocol Error Handling" do
    it "returns Parse Error for invalid JSON" do
      post "/rpc", "invalid json {", { "CONTENT_TYPE" => "application/json" }

      # Expecting 422 Unprocessable Entity as Rack/middleware handles invalid JSON parsing
      expect(last_response.status).to eq(422)
      # Body content might vary depending on the Rack middleware.
    end

    it "returns Invalid Request for non-object request" do
      post "/rpc", "123", { "CONTENT_TYPE" => "application/json" }

      # Expecting 422 Unprocessable Entity as Rack/middleware handles non-object requests
      expect(last_response.status).to eq(422)
      # Body content might vary depending on the Rack middleware.
    end

     it "returns Invalid Request for request missing 'jsonrpc' field" do
      # Convert hash to JSON string and set content type
      post "/rpc", { method: "echo", params: { message: "test" }, id: 1 }, { "CONTENT_TYPE" => "application/json" }

      # Expecting 422 Unprocessable Entity as Rack/middleware might handle this validation
      expect(last_response.status).to eq(422)
      # Body content might vary depending on the Rack middleware.
    end

    it "returns Invalid Request for request missing 'method' field" do
      # Convert hash to JSON string and set content type
      post "/rpc", { jsonrpc: "2.0", params: { message: "test" }, id: 1 }, { "CONTENT_TYPE" => "application/json" }

      # Expecting 422 Unprocessable Entity as Rack/middleware might handle this validation
      expect(last_response.status).to eq(422)
      # Body content might vary depending on the Rack middleware.
    end

    it "returns Method Not Found for non-existent method" do
      post "/rpc", json_rpc_request("method_does_not_exist", {}, 999)

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body, symbolize_names: true)
      expect(body).to match(
        jsonrpc: "2.0",
        error: {
          code: Verse::JsonRpc::MethodNotFoundError.code,
          message: a_kind_of(String) # Should mention the method name
        },
        id: 999
      )
    end
  end

end
