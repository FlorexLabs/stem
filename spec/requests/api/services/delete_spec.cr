require "../../../spec_helper"

describe Api::Services::Delete do
  it "deletes an existing service" do
    op = Service::SaveOperation.new
    op.name.value = "email-processor"
    op.kind.value = "Node.js"
    op.status.value = "ok"
    op.avg_response_ms.value = 10
    op.check_interval_seconds.value = 60
    op.timeout_seconds.value = 30
    op.save!

    service = ServiceQuery.new.name("email-processor").first

    response = ApiClient.exec(Api::Services::Delete.with(id: service.id))

    response.status_code.should eq(204)
    ServiceQuery.new.id(service.id).first?.should be_nil
  end

  it "returns 404 when trying to delete non-existing service" do
    response = ApiClient.exec(Api::Services::Delete.with(id: 999_i64))

    # if you switched to `ServiceQuery.find`, this would be 404 via error handler
    # if you kept the if/else, it's also 404 explicitly
    response.status_code.should eq(404)
  end
end
