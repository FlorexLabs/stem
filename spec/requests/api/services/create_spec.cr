require "../../../spec_helper"

describe Api::Services::Create do
  it "creates a service from JSON" do
    payload = {
      "name"          => "auth-service",
      "type"          => "Rails",
      "url"           => "https://auth.example.com",
      "checkInterval" => 60,
      "timeout"       => 30,
    }.to_json

    response = ApiClient.new
      .exec_raw(Api::Services::Create, payload)

    response.status_code.should eq(201)

    service = ServiceQuery.new.name("auth-service").first?
    service.should_not be_nil
    service.not_nil!.kind.should eq("Rails")
  end

  it "returns 422 on invalid data" do
    # missing name
    payload = {
      "type"          => "Rails",
      "checkInterval" => 60,
      "timeout"       => 30,
    }.to_json

    response = ApiClient.new
      .exec_raw(Api::Services::Create, payload)

    response.status_code.should eq(422)
    body = JSON.parse(response.body).as_h

    body.has_key?("errors").should be_true
  end
end
