# frozen_string_literal: true

module Verse
  module JsonRpc
    module Exposition
      # A hook is a single endpoint on the http server
      # @see Verse::Http::Exposition::Extension#on_http
      # @see Verse::Exposition::Base#expose
      class Hook < Verse::Exposition::Hook::Base
        attr_reader :name

        # Create a new hook
        # Used internally by the `on_json_rpc` method.
        # @see Verse::JsonRpc::Exposition::Extension#on_http
        def initialize(exposition, name)
          super(exposition)

          @name = name&.to_sym
        end

        # :nodoc:
        def register_impl
          hook = self
          controller = exposition_class.__json_rpc_controller__
          name = self.name || hook.method.name

          controller.add_method(name) do |expo_instance, params|
            safe_params = hook.metablock.process_input(params)

            # Tricky here: Because the call is going to
            # a http hook, then rerouted to another hook,
            # we must use the current exposition instance.
            # This is to make it work with batches for example.
            expo_instance.params = params

            result = expo_instance.run do
              hook.method.bind(self).call
            end

            if controller.validate_output?
              result = hook.metablock.process_output(result)
            end

            result
          end

        end
      end
    end
  end
end
