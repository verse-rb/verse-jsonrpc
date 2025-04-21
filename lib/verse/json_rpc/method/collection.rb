module JsonRpc
  module Method
    class Collection
      attr_reader :methods

      def initialize
        @methods = {}
      end

      def execute(method_name, id, params, exposition_instance)
        entry = fetch(method_name) do
          JsonRpc::MethodNotFoundError.new(id:)
        end

        output = entry.execute(
          id,
          params,
          exposition_instance
        )
      end

      def add(entry)
        @methods ||= {}

        method_name_sym = entry.name.to_sym
        raise "Method already registered: #{method_name}" if @methods.key?(method_name_sym)

        @methods[method_name_sym] = method

        self
      end
    end
  end
end
