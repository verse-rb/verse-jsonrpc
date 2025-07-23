# frozen_string_literal: true

module Verse
  module JsonRpc
    module Method
      Entry = Struct.new(:name, :input_schema, :output_schema, :callback, keyword_init: true) do
        def execute(id, params, exposition_instance)
          result = input_schema.validate(params)

          raise JsonRpc::InvalidParamsError.new(id:, data: result.errors) unless result.success?

          exposition_instance.instance_exec(params, &callback)
        end
      end
    end
  end
end
