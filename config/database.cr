database_name = ENV["DB_NAME"]? || "stem_#{LuckyEnv.environment}"

AppDatabase.configure do |settings|
  if LuckyEnv.production?
    # In production, prefer a single DATABASE_URL
    settings.credentials = Avram::Credentials.parse(ENV["DATABASE_URL"])
  else
    # In dev/test: use DATABASE_URL if present, else DB_* pieces
    settings.credentials =
      Avram::Credentials.parse?(ENV["DATABASE_URL"]?) ||
        Avram::Credentials.new(
          database: database_name,
          hostname: ENV["DB_HOST"]? || "localhost",
          port: ENV["DB_PORT"]?.try(&.to_i) || 5432,
          username: ENV["DB_USERNAME"]? || "postgres",
          password: ENV["DB_PASSWORD"]? || "postgres",
        )
  end
end

Avram.configure do |settings|
  settings.database_to_migrate = AppDatabase

  # In production, allow lazy loading (N+1).
  # In development and test, raise an error if you forget to preload associations
  settings.lazy_load_enabled = LuckyEnv.production?
end
