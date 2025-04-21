module Verse
  module JsonRpc
    module Method
      Entry = Struct.new(:name, :input_schema, :output_schema, :callback, keyword_init: true) do
        def execute(id, params, exposition_instance)
          result = input_schema.validate(params)

          if result.success?
            exposition_instance.instance_exec(params, &callback)
          else
            raise JsonRpc::InvalidParamsError.new(id:, data: result.errors)
          end
        end
      end
    end
  end
end