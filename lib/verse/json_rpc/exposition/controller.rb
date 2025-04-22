module Verse
  module JsonRpc
    module Exposition
      class Controller
        attr_reader :collection

        def initialize(validate_output: false)
          @collection = {}
          @validate_output = validate_output
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
            out << error.backtrace.map{ |x| "[#{@rid}] #{x}" }.join("\n")
          end

          out
        end

        protected def handle_batch(expo_instance, parans)
          # Batch processing
          params.map do |param|
            param => {id:, method:, params:}

            output = execute(method, id, expo_instance, params)
          end
        end

        protected def handle_single(expo_instance, params)
          params => {id:, method:, params:}

          execute(method, id, expo_instance, params)
        end

        def handle(expo_instance)
          params = expo_instance.params

          if params.is_a?(Array)
            # Batch request
            handle_batch(expo_instance, params)
          else
            # Single request
            handle_single(expo_instance, params)
          end
        end

        def execute(method, id, expo_instance, params)
          begin
            result = @collection.fetch(method) do
              raise JsonRpc::MethodNotFoundError.new(id: expo_instance.id)
            end.call(expo_instance, params)

            JsonRpc::CallResult.new(result:, id:)
          rescue JsonRpc::Error => e
            e
          rescue Verse::Error::ValidationFailed => e
            JsonRpc::InvalidParamsError.new(id:, data: e.source)
          rescue StandardError => e
            Verse.logger.warn(log_error(e))

            JsonRpc::InternalError.new(id:)
          end
        end
      end
    end
  end
end