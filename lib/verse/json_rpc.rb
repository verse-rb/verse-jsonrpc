# frozen_string_literal: true

require "verse/core"
require "verse/schema"
require "verse/http"

Dir["#{__dir__}/**/*.rb"].sort.each do |file|
  # do not load CLI nor specs files unless told otherwise.
  next if file =~ /(cli|spec)\.rb$/ ||
          file[__dir__.size..] =~ %r{^/(?:cli|spec)}

  require_relative file
end

Verse::Exposition::Base.extend(Verse::JsonRpc::Exposition::Extension)
