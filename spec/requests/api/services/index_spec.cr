require "../../../spec_helper"

describe Api::Services::Index do
  it "returns an empty list when there are no services" do
    response = ApiClient.exec(Api::Services::Index)

    response.status_code.should eq(200)
    body = JSON.parse(response.body)

    body.as_a.size.should eq(0)
  end

  it "lists existing services" do
    # create a service using the operation
    op = Service::SaveOperation.new
    op.name.value = "rails-api"
    op.kind.value = "Rails"
    op.status.value = "ok"
    op.avg_response_ms.value = 145
    op.check_interval_seconds.value = 60
    op.timeout_seconds.value = 30
    op.save!

    response = ApiClient.exec(Api::Services::Index)

    response.status_code.should eq(200)
    body = JSON.parse(response.body).as_a

    body.size.should eq(1)
    s = body.first.as_h
    s["name"].as_s.should eq("rails-api")
    s["status"].as_s.should eq("ok")
    s["type"].as_s.should eq("Rails")
    s["responseTime"].as_i.should eq(145)
  end
end
