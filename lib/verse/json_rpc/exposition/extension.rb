# frozen_string_literal: true

module Verse
  module JsonRpc
    module Exposition
      ##
      # The extension module for Verse::Http::Exposition::Base
      # @see Verse::Http::Exposition::Base
      module Extension
        def jsonrpc(
          http_path: "",
          http_method: :post,
          http_opts: {},
          &block
        )

          json_rpc_collection = DSL.new(&block)

          build_expose(
            on_http(http_method, http_path, **http_opts, renderer: Verse::JsonApi::Renderer)
          ) do
            desc "JSON-RPC API endpoint"

            input(JsonRpc::AllowedInput)
            output(JsonRpc::OutputSchema)
          end

          base_method = "jsonrpc_handler".to_sym

          if respond_to?(base_method)
            raise ArgumentError,
              "only one jsonrpc handler is authorized per exposition class"
          end

          # Useful for introspection/reflection/debugging
          define_class_method("jsonrpc_collection"){ json_rpc_collection }

          define_method(method) do
            output = nil

            if params.is_a?(Array)
              # Batch execution
              output = params.select do |param|
                rpc_method, id, rpc_params = params.values_at(:method, :id, :params)

                o = json_rpc_collection.execute(rpc_method, id, rpc_params, self)
                id ? o : nil # Discard if id is nil
              rescue JsonRpc::Error => error
                if id
                  JsonRpc::CallError.new(
                    error:,
                    id:,
                  )
                end
              end

              # As per JSON-RPC 2.0 spec, if the id is nil (notification),
              # the response should be 204 No Content
              output = nil if output.empty?
            else
              rpc_method, id, rpc_params = params.values_at(
                :method, :id, :params
              )

              output = \
                begin
                  # Simple execution
                  json_rpc_collection.execute(rpc_method, id, rpc_params, self)
                rescue JsonRpc::Error => error
                  JsonRpc::CallError.new(
                    error:,
                    id:,
                  )
                end

              # As per JSON-RPC 2.0 spec, if the id is nil (notification),
              # the response should be 204 No Content
              output = nil unless id

              # Change error code based on the output object:
              case output
              when nil
                server.response.status = 204
              when JsonRpc::ParseError
                server.response.status = 500
              when JsonRpc::InvalidRequestError
                server.response.status = 400
              when JsonRpc::MethodNotFoundError
                server.response.status = 404
              when JsonRpc::Error # other errors are 500
                server.response.status = 500
              else
                server.response.status = 200
              end

              output

            end
          end

        end
      end
    end
  end
end
