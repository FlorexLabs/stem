class Api::Services::Create < ApiAction
  post "/api/services" do
    data = params.from_json

    op = Service::SaveOperation.new
    op.name.value = data["name"].as_s
    op.kind.value = data["type"]?.try(&.as_s) || "Generic"
    op.url.value = data["url"]?.try(&.as_s)
    op.status.value = "ok"
    op.avg_response_ms.value = 0
    op.last_check.value = Time.utc
    op.check_interval_seconds.value = data["checkInterval"]?.try(&.as_i) || 60
    op.timeout_seconds.value = data["timeout"]?.try(&.as_i) || 30

    if op.save
      head 201
    else
      json({errors: op.errors}, 422)
    end
  end
end
