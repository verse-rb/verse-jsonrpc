module JsonRpc
  module Method
    Entry = Struct.new(:name, :input_schema, :callback) do
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
