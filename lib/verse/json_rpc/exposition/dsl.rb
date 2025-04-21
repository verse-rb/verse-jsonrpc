module JsonRpc
  module Exposition
    class DSL
      class MethodDSL
        attr_chainable :desc

        def initialize(&block)
          instance_eval(&block)
        end

        def input(value = Nothing, &block)
          if value != Nothing
            if block_given?
              raise ArgumentError, "input value and block given at the same time"
            end

            @input = value
            self
          elsif block_given?
            Verse::Schema.define(&block)
            self
          else
            @input
          end
        end

        def output(&block)
          if value != Nothing
            if block_given?
              raise ArgumentError, "output value and block given at the same time"
            end

            @output = value
            self
          elsif block_given?
            Verse::Schema.define(&block)
            self
          else
            @output
          end
        end
      end

      attr_reader :methods

      def initialize(&block)
        @methods = Method::Collection.new
        instance_eval(&block)
      end

      def method(name, &block)
        output = MethodDSL.new(&block).entry
        methods.add(method.name, method)
      end
    end
  end
end