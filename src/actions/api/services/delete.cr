class Api::Services::Delete < ApiAction
  delete "/api/services/:id" do
    id = params.get(:id)
    if service = ServiceQuery.new.id(id).first?
      Service::DeleteOperation.delete!(service)
      head 204
    else
      head 404
    end
  end
end
