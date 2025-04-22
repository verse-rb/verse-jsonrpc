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
            message: "Invalid params",
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
        binding.pry
        expect(body).to match(
          jsonrpc: "2.0",
          error: {
            code: Verse::JsonRpc::InternalError.code, # Or a more specific code if mapped
            message: "Validation Failed: This is a test error",
            data: a_kind_of(Hash) # May contain stack trace or other details depending on config
          },
          id: request_id
        )
      end
    end

    context "when calling the 'public_method'" do
      let(:method) { "public_method" }
      let(:params) { { value: 10 } }
      let(:request_id) { 789 }

      it "executes successfully without authentication" do
        post "/rpc", json_rpc_request(method, params, request_id)

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body, symbolize_names: true)
        expect(body).to eq(
          jsonrpc: "2.0",
          result: { result: 20 },
          id: request_id
        )
      end
    end

    context "when sending a 'notify_only' notification" do
      let(:method) { "notify_only" }
      let(:params) { { data: "Important notification" } }

      it "returns an empty response (HTTP 204 or 200 OK)" do
        # Notifications have no 'id'
        post "/rpc", json_rpc_notification(method, params)

        # JSON-RPC notifications might return 204 No Content or 200 OK with empty body.
        # Check for either, or adjust based on the specific server behavior.
        expect([200, 204]).to include(last_response.status)

        # Expect an empty body for notifications
        expect(last_response.body).to be_empty
      end
    end
  end

  describe "Batch Request Handling" do
    it "handles a batch of valid requests (including success and error)" do
      batch_request = [
        json_rpc_request("public_method", { value: 5 }, 1),
        json_rpc_notification("notify_only", { data: "batch notification" }), # Notification in batch
        json_rpc_request("echo", { message: "Batch Echo" }, 2), # Auth required, no creds -> error
        json_rpc_request("non_existent_method", {}, 3), # Method not found error
        json_rpc_request("raise_error", {}, 4) # Internal error
      ]

      post "/rpc", batch_request # Send the array as the body

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body, symbolize_names: true)
      expect(body).to be_an(Array)
      expect(body.size).to eq(4) # 4 responses expected (notification doesn't get one)

      # Check responses (order should match request order, excluding notification)
      expect(body).to contain_exactly(
        # Response for public_method (id: 1)
        a_hash_including(jsonrpc: "2.0", result: { result: 10 }, id: 1),
        # Response for echo (id: 2) - Auth error
        a_hash_including(
          jsonrpc: "2.0",
          error: a_hash_including(code: Verse::JsonRpc::Errors::AUTHENTICATION_ERROR),
          id: 2
        ),
        # Response for non_existent_method (id: 3) - Method not found
        a_hash_including(
          jsonrpc: "2.0",
          error: a_hash_including(code: Verse::JsonRpc::Errors::METHOD_NOT_FOUND),
          id: 3
        ),
        # Response for raise_error (id: 4) - Internal error
        a_hash_including(
          jsonrpc: "2.0",
          error: a_hash_including(
            code: Verse::JsonRpc::Errors::INTERNAL_ERROR,
            message: "Validation Failed: This is a test error"
          ),
          id: 4
        )
      )
    end

    it "handles an empty batch request array" do
      post "/rpc", []

      expect(last_response.status).to eq(200) # Or potentially a specific error? Check spec. JSON-RPC spec says Invalid Request.
      body = JSON.parse(last_response.body, symbolize_names: true)
      expect(body).to match(
        jsonrpc: "2.0",
        error: {
          code: Verse::JsonRpc::Errors::INVALID_REQUEST,
          message: a_kind_of(String)
        },
        id: nil # Error for invalid request structure often has null id
      )
    end

    it "handles a batch containing only notifications" do
      batch_request = [
        json_rpc_notification("notify_only", { data: "notify 1" }),
        json_rpc_notification("notify_only", { data: "notify 2" })
      ]

      post "/rpc", batch_request

      # Should return no content as all requests were notifications
      expect([200, 204]).to include(last_response.status)
      expect(last_response.body).to be_empty
    end

    it "returns a single error response if the batch array itself is invalid JSON (handled by Rack/middleware)" do
      # This tests the layer before JSON-RPC parsing
      post "/rpc", "[{\"jsonrpc\": \"2.0\", \"method\": \"echo\", \"params\": {\"message\": \"Valid\"}, \"id\": 1}, InvalidJSON]", content_type: "application/json"

      # Expect a generic HTTP error or a JSON-RPC Parse Error depending on middleware
      # For now, let's assume it results in a Parse Error from the JSON-RPC handler perspective
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body, symbolize_names: true)
      expect(body).to match(
        jsonrpc: "2.0",
        error: {
          code: Verse::JsonRpc::Errors::PARSE_ERROR,
          message: a_kind_of(String)
        },
        id: nil
      )
    end
  end

  describe "Protocol Error Handling" do
    it "returns Parse Error for invalid JSON" do
      post "/rpc", "invalid json {", content_type: "application/json"

      expect(last_response.status).to eq(200) # JSON-RPC errors return HTTP 200
      body = JSON.parse(last_response.body, symbolize_names: true)
      expect(body).to match(
        jsonrpc: "2.0",
        error: {
          code: Verse::JsonRpc::Errors::PARSE_ERROR,
          message: a_kind_of(String) # Specific message might vary based on parser
        },
        id: nil # Parse errors might not be able to determine an ID
      )
    end

    it "returns Invalid Request for non-object request" do
      post "/rpc", "123", content_type: "application/json"

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body, symbolize_names: true)
      expect(body).to match(
        jsonrpc: "2.0",
        error: {
          code: Verse::JsonRpc::Errors::INVALID_REQUEST,
          message: a_kind_of(String)
        },
        id: nil
      )
    end

     it "returns Invalid Request for request missing 'jsonrpc' field" do
      post "/rpc", { method: "echo", params: { message: "test" }, id: 1 }

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body, symbolize_names: true)
      expect(body).to match(
        jsonrpc: "2.0",
        error: {
          code: Verse::JsonRpc::Errors::INVALID_REQUEST,
          message: a_kind_of(String) # Should mention missing 'jsonrpc'
        },
        id: 1 # ID might be present in this case
      )
      expect(body[:error][:message]).to include("jsonrpc")
    end

    it "returns Invalid Request for request missing 'method' field" do
      post "/rpc", { jsonrpc: "2.0", params: { message: "test" }, id: 1 }

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body, symbolize_names: true)
      expect(body).to match(
        jsonrpc: "2.0",
        error: {
          code: Verse::JsonRpc::Errors::INVALID_REQUEST,
          message: a_kind_of(String) # Should mention missing 'method'
        },
        id: 1
      )
       expect(body[:error][:message]).to include("method")
    end

    it "returns Method Not Found for non-existent method" do
      post "/rpc", json_rpc_request("method_does_not_exist", {}, 999)

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body, symbolize_names: true)
      expect(body).to match(
        jsonrpc: "2.0",
        error: {
          code: Verse::JsonRpc::Errors::METHOD_NOT_FOUND,
          message: a_kind_of(String) # Should mention the method name
        },
        id: 999
      )
      expect(body[:error][:message]).to include("method_does_not_exist")
    end

    # Invalid Params is already tested within the 'echo' method context.
    # Internal Error is already tested within the 'raise_error' method context.
  end

end
