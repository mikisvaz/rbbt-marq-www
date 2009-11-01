require File.join(File.dirname(__FILE__), '..', 'spec_helper.rb')

describe "/results" do
  before(:each) do
    @response = request("/results")
  end
end