# frozen_string_literal: true


module Verse
  module JsonRpc
    def self.register(path = "_jsonapi", collection = :default)
    end
  end
end

require_relative "json_rpc/version"
require_relative "json_rpc/errors"
require_relative "json_rpc/schemas"
require_relative "json_rpc/method"