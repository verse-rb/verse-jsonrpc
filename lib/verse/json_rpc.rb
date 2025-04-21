# frozen_string_literal: true

require "verse/core"
require "verse/http"

require "verse/schema"


module Verse
  module JsonRpc
  end
end

require_relative "json_rpc/version"

Dir["#{__dir__}/**/*.rb"].sort.each do |file|
  # do not load CLI nor specs files unless told otherwise.
  next if file =~ /(cli|spec)\.rb$/ ||
          file[__dir__.size..] =~ %r{^/(?:cli|spec)}

  require_relative file
end

Verse::Exposition::Base.extend(Verse::JsonRpc::Exposition::Extension)