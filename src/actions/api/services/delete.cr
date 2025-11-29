class Api::Services::Delete < ApiAction
  include Api::Auth::SkipRequireAuthToken

  delete "/api/services/:id" do
    service = ServiceQuery.find(params.get(:id))
    DeleteService.delete!(service)
    head 204
  end
end
