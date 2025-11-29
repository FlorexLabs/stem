class Api::Services::Index < ApiAction
  include Api::Auth::SkipRequireAuthToken

  get "/api/services" do
    services = ServiceQuery.new.id.asc_order.results
    json ServiceSerializer.for_collection(services)
  end
end
