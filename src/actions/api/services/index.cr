class Api::Services::Index < ApiAction
  include Api::Auth::SkipRequireAuthToken

  get "/api/services" do
    services = ServiceQuery.new.id.asc_order
    json services.map { |s| ServiceSerializer.new(s).to_json }
  end
end
