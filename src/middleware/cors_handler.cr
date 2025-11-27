class CorsHandler
  include HTTP::Handler

  def call(context : HTTP::Server::Context)
    res = context.response
    res.headers["Access-Control-Allow-Origin"] = ENV["CORS_ORIGIN"]? || "*"
    res.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
    res.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"

    if context.request.method == "OPTIONS"
      res.status_code = 204
      return
    end

    call_next(context)
  end
end
