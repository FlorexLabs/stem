class Api::Health::Show < ApiAction
  get "/api/health" do
    json({ok: true, version: "0.1.0"})
  end
end
