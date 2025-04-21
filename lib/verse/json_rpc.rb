# frozen_string_literal: true

require "verse/schema"

module Verse
  module JsonRpc
  end
end

require_relative "json_rpc/version"

require_relative "json_rpc/errors"
require_relative "json_rpc/output"
require_relative "json_rpc/schemas"
require_relative "json_rpc/method/collection"