module Verse
  module JsonRpc
    module Exposition
      class Controller
        attr_reader :collection, :batch_limit

        def initialize(validate_output: false, batch_limit: 100)
          @collection = {}
          @validate_output = validate_output
          @batch_limit = batch_limit
        end

        def validate_output? = !!@validate_output

        def add_method(name, &method)
          if @collection.key?(name)
            raise "Method already registered: #{name}"
          end

          @collection[name] = method

          self
        end

        def log_error(error)
          out = "#{error.class.name} (#{error.message})"

          if error.backtrace
            out << "\n"
            out << error.backtrace.join("\n")
          end

          out
        end

        protected def handle_batch(expo_instance, params)
          # Batch processing
          params.map do |param|
            id, method, params = param.values_at(:id, :method, :params)

            output = execute(method, id, expo_instance, params)
            id && output
          end.compact
        end

        protected def handle_single(expo_instance, params)
          id, method, params = params.values_at(:id, :method, :params)

          out = execute(method, id, expo_instance, params)
          id && out
        end

        def handle(expo_instance)
          params = expo_instance.params

          if (arr = params[:_body]) && arr.is_a?(Array)
            if @batch_limit && arr.size > @batch_limit
              raise JsonRpc::InvalidRequestError.new(
                message: "Batch size limit exceeded",
                data: { batch_limit: @batch_limit }
              )
            end

            # Batch request
            handle_batch(expo_instance, arr)
          else
            # Single request
            handle_single(expo_instance, params)
          end
        end

        def execute(method, id, expo_instance, params)
          begin
            result = @collection.fetch(method) do
              raise JsonRpc::MethodNotFoundError.new(
                id:
              )
            end.call(expo_instance, params)

            JsonRpc::CallResult.new(result:, id:)
          rescue JsonRpc::Error => e
            e
          rescue Verse::Error::ValidationFailed => e
            JsonRpc::InvalidParamsError.new(
              id:,
              message: e.message,
              data: e.source
            )
          rescue StandardError => e
            Verse.logger.warn(log_error(e))

            JsonRpc::InternalError.new(id:, message: e.message)
          end
        end
      end
    end
  end
end