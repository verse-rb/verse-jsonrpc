# frozen_string_literal: true

module Verse
  module JsonRpc
    module Exposition
      class DSL
        class MethodDSL
          attr_chainable :desc, :name

          def initialize(&block)
            instance_eval(&block)
          end

          def input(value = Nothing, &block)
            if value != Nothing
              raise ArgumentError, "input value and block given at the same time" if block_given?

              @input = value
              self
            elsif block_given?
              @input = Verse::Schema.define(&block)
              self
            else
              @input
            end
          end

          def output(value = Nothing, &block)
            if value != Nothing
              raise ArgumentError, "output value and block given at the same time" if block_given?

              @output = value
              self
            elsif block_given?
              @output = Verse::Schema.define(&block)
              self
            else
              @output
            end
          end

          def call(&block)
            @call = block
            self
          end

          def entry
            Method::Entry.new(
              name:,
              input_schema: input,
              output_schema: output,
              callback: call
            )
          end
        end

        attr_reader :methods

        def initialize(&block)
          @methods = Method::Collection.new
          instance_eval(&block)
        end

        def method(name, &block)
          output = MethodDSL.new(&block).name(name).entry
          methods.add(output)
        end
      end
    end
  end
end
