# frozen_string_literal: true

RSpec.describe Verse::Jsonrpc do
  it "has a version number" do
    expect(Verse::Jsonrpc::VERSION).not_to be nil
  end
end
