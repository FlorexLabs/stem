class Api::Services::Create < ApiAction
  include Api::Auth::SkipRequireAuthToken

  post "/api/services" do
    data = params.from_json

    op = SaveService.new
    op.name.value = data["name"]?.try(&.as_s)
    op.kind.value = data["type"]?.try(&.as_s) || "Generic"
    op.url.value = data["url"]?.try(&.as_s)
    op.check_interval_seconds.value = data["checkInterval"]?.try(&.as_i) || 60
    op.timeout_seconds.value = data["timeout"]?.try(&.as_i) || 30

    if op.save
      head 201
    else
      json({errors: op.full_messages}, 422)
    end
  end
end
