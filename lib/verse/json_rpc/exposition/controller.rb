module Verse
  module JsonRpc
    module Exposition
      class Controller
        attr_reader :collection, :validate_output

        def initialize(validate_output: false)
          @collection = {}
          @validate_output = validate_output
        end

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

        def handle(expo_instance)
          params = expo_instance.params

          if params.is_a?(Array)
            # Batch processing
            params.each do |param|
              param => {id:, method:, params:}

              output = \
                begin
                  execute(method, id, expo_instance, params)
                rescue JsonRpc::Error => e
                  output
                rescue StandardError => e
                  # Not great, but
                  # We cannot use the
                  # default logger handler
                  # from exposition handler
                  # stack :(
                  Verse.logger.warn(log_error(e))

                  JsonRpc::InternalError.new(id:)
                end

            end


          else
            # Single request
          end
        end

        def execute(method, id, expo_instance, params)
          result = @collection.fetch(method) do
            raise JsonRpc::MethodNotFoundError.new(id: expo_instance.id)
          end.call(expo_instance, params)

          CallResult.new(result:, id:)
        end
      end
    end
  end
end