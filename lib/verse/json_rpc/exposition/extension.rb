# frozen_string_literal: true

require_relative "./param_schemas"

module Verse
  module JsonRpc
    module Exposition
      module Extension
        # Hook on json-rpc method
        def json_rpc_method(method = nil)
          Hook.new(self, method)
        end

        def __json_rpc_controller__
          if @__json_rpc_controller__.nil?
            # :nocov:
            raise "the json rpc controller is not setup. " \
                  "use json_rpc to initialize your exposition to json_rpc"
            # :nocov:
          end

          @__json_rpc_controller__
        end

        def json_rpc(
          http_path: "",
          http_method: :post,
          http_opts: {},
          validate_output: false,
          batch_limit: 100,
          batch_failure: :continue
        )
          @__json_rpc_controller__ = Controller.new(validate_output:, batch_limit:)

          base_method = :__jsonrpc_handler__

          if respond_to?(base_method)
            # :nocov:
            raise ArgumentError,
                  "only one jsonrpc handler is authorized per exposition class"
            # :nocov:
          end

          exposition = build_expose(
            on_http(http_method, http_path, **http_opts, renderer: Verse::JsonRpc::Renderer)
          ) do
            desc "JSON-RPC API endpoint"
            input(JsonRpc::AllowedInput)
            output(JsonRpc::OutputSchema)
          end

          define_method(base_method) do
            # the outer, request-level auth-checked
            # gate is redundant for JSON-RPC — real per-action authorization is already
            # enforced independently by each method's own repository call
            # (scoped()/can!). The outer gate should stop trying to infer "was auth
            # checked" from whether any item happened to reach business logic, and instead
            # just be marked satisfied up front for JSON-RPC requests, since the inner,
            # per-item mechanism is what's actually doing the enforcement.
            auth_context.mark_as_checked!
            self.class.__json_rpc_controller__.handle(self, batch_failure:)
          end

          attach_exposition base_method, exposition
        end
      end
    end
  end
end
