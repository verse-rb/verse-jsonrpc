# Verse::JsonRpc

This gem provides JSON-RPC 2.0 support for Verse applications, allowing you to expose methods over HTTP using the JSON-RPC protocol.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'verse-jsonrpc'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install verse-jsonrpc
```

## Usage

To expose methods via JSON-RPC, use the `json_rpc` helper within your Verse exposition class. Define your RPC methods using `json_rpc_method` hook.

```ruby
# frozen_string_literal: true

class MyRpcExpo < Verse::Exposition::Base
  # Configure the JSON-RPC endpoint
  # Set the HTTP path and batch limit (optional)
  json_rpc http_path: "rpc", batch_limit: 5

  # Define the 'echo' method using the expose helper
  # The method name is inferred from the method definition below
  expose json_rpc_method do
    input do
      # Define input schema using Verse::Schema
      field(:message, String)
    end
    output do
      # Define output schema using Verse::Schema
      field(:echo_message, String)
    end
  end
  def echo
    # Access validated parameters via the `params` method
    { echo_message: "Echo: #{params[:message]}" }
  end

  # Define the 'raise_error' method
  expose json_rpc_method do
    desc "A method that always raises an error"
    # No input or output schema needed if none are defined
  end
  def raise_error
    raise StandardError, "This is a test error" # Use StandardError or custom errors
  end

  # Note: The actual method implementation (`def echo`, `def raise_error`)
  # contains the logic executed when the RPC method is called.
  # The `expose json_rpc_method` block defines metadata like input/output schemas
end

# Register the exposition in routes.rb:
# MyRpcExpo.register
```

### Calling the RPC Endpoint

You can call the endpoint using standard JSON-RPC 2.0 requests via HTTP POST:

**Single Request:**

```json
POST /rpc
Content-Type: application/json

{
  "jsonrpc": "2.0",
  "method": "echo",
  "params": { "message": "Hello Verse!" },
  "id": 1
}
```

**Response:**

```json
{
  "jsonrpc": "2.0",
  "result": { "echo_message": "Echo: Hello Verse!" },
  "id": 1
}
```

**Batch Request:**

```json
POST /rpc
Content-Type: application/json

[
  { "jsonrpc": "2.0", "method": "echo", "params": { "message": "Request 1" }, "id": 10 },
  { "jsonrpc": "2.0", "method": "raise_error", "id": 11 },
  { "jsonrpc": "2.0", "method": "non_existent_method", "id": 12 }
]
```

**Response:**

```json
[
  { "jsonrpc": "2.0", "result": { "echo_message": "Echo: Request 1" }, "id": 10 },
  { "jsonrpc": "2.0", "error": { "code": -32603, "message": "Internal error", "data": "This is a test error" }, "id": 11 },
  { "jsonrpc": "2.0", "error": { "code": -32601, "message": "Method not found" }, "id": 12 }
]
```

## Limits

- You can define only one endpoint per Exposition Class. If you want multiple
`JSON:RPC` endpoint, you need to create multiple exposition classes.
- Authentication is managed via the verse-http exposition layer. You can use
  `http_opts` to pass authentication options.
- Resource based access is made using `auth_context` as usual.

## Options

When configuring the JSON-RPC endpoint with `json_rpc`, you can provide the following options:

*   `http_path` (String, default: `""`): The URL path for the JSON-RPC endpoint.
    It will concatenate the `http_path` of the exposition if any.
*   `http_method` (Symbol, default: `:post`): The HTTP method to use for the endpoint.
*   `http_opts` (Hash, default: `{}`): Additional options passed to the underlying HTTP exposition layer, like `auth:`.
*   `validate_output` (Boolean, default: `false`): Whether to validate the output of RPC methods against their defined output schemas. Can impact performance.
*   `batch_limit` (Integer, default: `100`): The maximum number of requests allowed in a single batch call. Put to `0` to disable batch processing and `nil` to disable the limit.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Contributing

Bug reports and pull requests are welcome on GitHub [here](https://github.com/verse-rb/verse-jsonrpc). This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

1.  Fork it (`https://github.com/verse-rb/verse-jsonrpc/fork`)
2.  Create your feature branch (`git checkout -b my-new-feature`)
3.  Commit your changes (`git commit -am 'Add some feature'`)
4.  Push to the branch (`git push origin my-new-feature`)
5.  Create a new Pull Request
