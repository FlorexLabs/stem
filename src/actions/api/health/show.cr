class Api::Health::Show < ApiAction
  include Api::Auth::SkipRequireAuthToken

  get "/api/health" do
    json({ok: true, version: "0.1.0"})
  end
end
