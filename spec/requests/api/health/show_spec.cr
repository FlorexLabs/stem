require "../../../spec_helper"

describe Api::Health::Show do
  it "returns ok and version" do
    response = ApiClient.exec(Api::Health::Show)

    response.status_code.should eq(200)
    body = JSON.parse(response.body).as_h

    body["ok"].as_bool.should be_true
    body["version"].as_s.should eq("0.1.0")
  end
end
