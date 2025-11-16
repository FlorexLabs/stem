# src/stem.cr
require "kemal"
require "pg"
require "json"
require "uri"
require "dotenv"

# ============
# DB bootstrap
# ============
module Stem
  VERSION = "0.1.0"

  Dotenv.load
  DEFAULT_DB_URL = "postgres://postgres:postgres@127.0.0.1:5432/florex"

  @@db : DB::Database?

  def self.db : DB::Database
    @@db ||= DB.open(ENV["DATABASE_URL"]? || DEFAULT_DB_URL)
  end

  def self.migrate!
    db = self.db

    db.exec <<-SQL
      CREATE TABLE IF NOT EXISTS services (
        id BIGSERIAL PRIMARY KEY,
        name TEXT UNIQUE NOT NULL,
        kind TEXT NOT NULL,
        url TEXT,
        status TEXT NOT NULL DEFAULT 'ok',
        avg_response_ms INT NOT NULL DEFAULT 0,
        last_check TIMESTAMPTZ,
        check_interval_seconds INT NOT NULL DEFAULT 60,
        timeout_seconds INT NOT NULL DEFAULT 30,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    SQL

    db.exec <<-SQL
      CREATE TABLE IF NOT EXISTS service_metrics (
        id BIGSERIAL PRIMARY KEY,
        service_id BIGINT NOT NULL REFERENCES services(id) ON DELETE CASCADE,
        ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        response_ms INT NOT NULL,
        status TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_service_metrics_service_ts ON service_metrics(service_id, ts DESC);
    SQL

    db.exec <<-SQL
      CREATE TABLE IF NOT EXISTS logs (
        id BIGSERIAL PRIMARY KEY,
        service_id BIGINT NOT NULL REFERENCES services(id) ON DELETE CASCADE,
        ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        message TEXT NOT NULL,
        severity TEXT NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_logs_service_ts ON logs(service_id, ts DESC);
      CREATE INDEX IF NOT EXISTS idx_logs_severity_ts ON logs(severity, ts DESC);
    SQL

    db.exec <<-SQL
      CREATE TABLE IF NOT EXISTS alerts (
        id BIGSERIAL PRIMARY KEY,
        service_id BIGINT NOT NULL REFERENCES services(id) ON DELETE CASCADE,
        severity TEXT NOT NULL,
        message TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        resolved_at TIMESTAMPTZ
      );
      CREATE INDEX IF NOT EXISTS idx_alerts_open ON alerts(service_id) WHERE resolved_at IS NULL;
    SQL

    db.exec <<-SQL
      CREATE TABLE IF NOT EXISTS alert_channels (
        id BIGSERIAL PRIMARY KEY,
        kind TEXT NOT NULL,
        enabled BOOLEAN NOT NULL DEFAULT FALSE,
        config JSONB NOT NULL DEFAULT '{}'::jsonb,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
      CREATE UNIQUE INDEX IF NOT EXISTS uniq_alert_channels_kind ON alert_channels(kind);
    SQL
  end

  def self.seed!
    db = self.db

    # Services
    count = db.scalar("SELECT COUNT(*) FROM services").as(Int64)
    if count == 0
      db.exec <<-SQL
        INSERT INTO services (name, kind, url, status, avg_response_ms, last_check, check_interval_seconds, timeout_seconds)
        VALUES
          ('rails-api', 'Rails', 'https://api.example.com', 'ok', 145, NOW() - INTERVAL '2 minutes', 60, 30),
          ('node-worker', 'Node.js', 'https://worker.example.com', 'ok', 89, NOW() - INTERVAL '1 minutes', 60, 30),
          ('auth-service', 'Rails', 'https://auth.example.com', 'warning', 312, NOW() - INTERVAL '3 minutes', 60, 30),
          ('websocket-server', 'Node.js', 'wss://ws.example.com', 'ok', 52, NOW() - INTERVAL '1 minutes', 30, 10),
          ('payment-gateway', 'Rails', 'https://pay.example.com', 'ok', 198, NOW() - INTERVAL '2 minutes', 60, 30),
          ('email-processor', 'Node.js', 'https://mail.example.com', 'error', 0, NOW() - INTERVAL '5 minutes', 60, 30)
      SQL

      # Seed some metrics (last 12 points-ish)
      db.query "SELECT id, name FROM services" do |rs|
        while rs.move_next
          sid = rs.read(Int64)
          name = rs.read(String)
          # simple synthetic metrics
          12.times do |i|
            delay_ms = case name
              when "email-processor" then i < 5 ? 40 + 5*i : 0
              when "auth-service"    then 220 + (i*15)
              when "rails-api"       then 120 + (i%5)*5
              when "node-worker"     then 80 + (i%5)*3
              when "websocket-server" then 50 + (i%5)*2
              when "payment-gateway" then 160 + (i%5)*8
              else 100
            end
            st = delay_ms == 0 ? "error" : (delay_ms > 250 ? "warning" : "ok")
            db.exec "INSERT INTO service_metrics (service_id, ts, response_ms, status) VALUES ($1, NOW() - ($2 || ' minutes')::interval, $3, $4)",
              sid, (12 - i), delay_ms, st
          end
        end
      end

      # Alerts
      db.exec <<-SQL
        INSERT INTO alerts (service_id, severity, message, created_at)
        SELECT s.id, 'critical', 'Service is down - Connection timeout', NOW()
        FROM services s WHERE s.name = 'email-processor';
        INSERT INTO alerts (service_id, severity, message, created_at)
        SELECT s.id, 'warning', 'High response time detected (>300ms)', NOW() - INTERVAL '5 minutes'
        FROM services s WHERE s.name = 'auth-service';
        INSERT INTO alerts (service_id, severity, message, created_at)
        SELECT s.id, 'info', 'Service recovered', NOW() - INTERVAL '30 minutes'
        FROM services s WHERE s.name = 'rails-api';
      SQL

      # Logs
      db.exec <<-SQL
        INSERT INTO logs (service_id, ts, message, severity)
        SELECT s.id, NOW() - INTERVAL '0 minutes', 'Connection timeout after 30 seconds', 'critical'
        FROM services s WHERE s.name = 'email-processor';
        INSERT INTO logs (service_id, ts, message, severity)
        SELECT s.id, NOW() - INTERVAL '1 minutes', 'Retry attempt 3/3 failed', 'error'
        FROM services s WHERE s.name = 'email-processor';
        INSERT INTO logs (service_id, ts, message, severity)
        SELECT s.id, NOW() - INTERVAL '5 minutes', 'Response time 312ms exceeds threshold', 'warning'
        FROM services s WHERE s.name = 'auth-service';
        INSERT INTO logs (service_id, ts, message, severity)
        SELECT s.id, NOW() - INTERVAL '8 minutes', 'Health check passed', 'info'
        FROM services s WHERE s.name = 'rails-api';
      SQL

      # Alert channels
      db.exec <<-SQL
        INSERT INTO alert_channels (kind, enabled, config)
        VALUES
          ('email', TRUE, '{"recipients": ["admin@example.com"]}'),
          ('slack', TRUE, '{"webhook_url": "https://hooks.slack.com/services/..."}'),
          ('telegram', FALSE, '{"bot_token": "", "chat_id": ""}'),
          ('mattermost', FALSE, '{"webhook_url": ""}')
        ON CONFLICT (kind) DO NOTHING;
      SQL
    end
  end
end

# ==================
# DTOs (camelCased)
# ==================
struct ServiceDTO
  include JSON::Serializable

  property id : Int64
  property name : String
  @[JSON::Field(key: "type")]
  property kind : String
  property status : String
  @[JSON::Field(key: "responseTime")]
  property response_time : Int32
  @[JSON::Field(key: "lastCheck")]
  property last_check_human : String
  property sparkline : Array(Int32)

  def initialize(
    @id : Int64,
    @name : String,
    @kind : String,
    @status : String,
    @response_time : Int32,
    @last_check_human : String,
    @sparkline : Array(Int32)
  ); end
end

struct LogDTO
  include JSON::Serializable

  property id : Int64
  property timestamp : String
  property service : String
  property message : String
  property severity : String

  def initialize(
    @id : Int64,
    @timestamp : String,
    @service : String,
    @message : String,
    @severity : String
  ); end
end

struct AlertDTO
  include JSON::Serializable

  property id : Int64
  property service : String
  property message : String
  property severity : String
  property timestamp : String

  def initialize(
    @id : Int64,
    @service : String,
    @message : String,
    @severity : String,
    @timestamp : String
  ); end
end

struct AlertChannelDTO
  include JSON::Serializable

  property id : Int64
  property name : String
  property enabled : Bool
  property config : JSON::Any
  @[JSON::Field(key: "icon")]
  property icon_path : String

  def initialize(
    @id : Int64,
    @name : String,
    @enabled : Bool,
    @config : JSON::Any,
    @icon_path : String
  ); end
end

# ===========
# Utilities
# ===========
def time_ago(ts : Time?) : String
  return "—" unless ts
  diff = Time.utc - ts
  mins = (diff.total_minutes).to_i
  return "#{mins} min ago" if mins < 60
  hours = (diff.total_hours).to_i
  return "#{hours} hour ago" if hours == 1
  return "#{hours} hours ago" if hours < 24
  days = (diff.total_days).to_i
  days == 1 ? "1 day ago" : "#{days} days ago"
end

def normalize_spark(values : Array(Int32)) : Array(Int32)
  max = values.max? || 1
  return values.map { |v| 0 } if max == 0
  values.map { |v| ((v.to_f / max) * 100.0).round.to_i }
end

def icon_for_channel(kind : String) : String
  case kind
  when "email"
    "M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
  when "slack"
    "M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
  when "telegram"
    "M12 19l9 2-9-18-9 18 9-2zm0 0v-8"
  when "mattermost"
    "M17 8h2a2 2 0 012 2v6a2 2 0 01-2 2h-2v4l-4-4H9a1.994 1.994 0 01-1.414-.586m0 0L11 14h4a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2v4l.586-.586z"
  else
    ""
  end
end

# ==================
# CORS + JSON helper
# ==================
before_all do |env|
  env.response.headers["Access-Control-Allow-Origin"] = ENV["CORS_ORIGIN"]? || "*"
  env.response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
  env.response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
end

options "/*" do |env|
  env.response.status_code = 204
  ""
end

def json(env, payload, status = 200)
  env.response.status_code = status
  env.response.content_type = "application/json"
  payload.to_json
end

# =========
# Routes
# =========
get "/api/health" { |env| json(env, {ok: true, version: Stem::VERSION}) }

# Summary for hero cards
get "/api/status" do |env|
  db = Stem.db
  total = db.scalar("SELECT COUNT(*) FROM services").as(Int64)
  healthy = db.scalar("SELECT COUNT(*) FROM services WHERE status = 'ok'").as(Int64)
  active_alerts = db.scalar("SELECT COUNT(*) FROM alerts WHERE resolved_at IS NULL AND severity IN ('critical','error')").as(Int64) rescue 0_i64
  uptime = 99.8 # placeholder – compute properly later from metrics

  json(env, {
    services: total,
    healthy: healthy,
    activeAlerts: active_alerts,
    uptimePercent: uptime,
  })
end

# List services (with sparkline)
get "/api/services" do |env|
  db = Stem.db
  services = [] of ServiceDTO

  db.query "SELECT id, name, kind, status, avg_response_ms, last_check FROM services ORDER BY name" do |rs|
    while rs.move_next
      id = rs.read(Int64)
      name = rs.read(String)
      kind = rs.read(String)
      status = rs.read(String)
      avg_rt = rs.read(Int32)
      last_check = rs.read(Time?)
      # load last 12 response_ms for sparkline
      points = [] of Int32
      db.query "SELECT response_ms FROM service_metrics WHERE service_id = $1 ORDER BY ts DESC LIMIT 12", id do |rs2|
        while rs2.move_next
          points << rs2.read(Int32)
        end
      end
      points = points.reverse
      services << ServiceDTO.new(
        id: id,
        name: name,
        kind: kind,
        status: status,
        response_time: avg_rt,
        last_check_human: time_ago(last_check),
        sparkline: normalize_spark(points)
      )
    end
  end

  json(env, services)
end

# Service detail + last 24h points
get "/api/services/:id" do |env|
  db = Stem.db
  id = env.params.url["id"].to_i64

  row = db.query_one? "SELECT id, name, kind, status, avg_response_ms, last_check FROM services WHERE id = $1", id, as: {
    Int64, String, String, String, Int32, Time?
  }

  unless row
    env.response.status_code = 404
    next json(env, {error: "Service not found"})
  end

  sid, name, kind, status, avg_rt, last_check = row

  points = [] of Int32
  db.query "SELECT response_ms FROM service_metrics WHERE service_id = $1 AND ts >= NOW() - INTERVAL '24 hours' ORDER BY ts ASC", id do |rs2|
    while rs2.move_next
      points << rs2.read(Int32)
    end
  end

  dto = ServiceDTO.new(
    id: sid,
    name: name,
    kind: kind,
    status: status,
    response_time: avg_rt,
    last_check_human: time_ago(last_check),
    sparkline: normalize_spark(points.last(12)) # keep last 12 for UI
  )

  json(env, dto)
end

# Create a service (simple)
post "/api/services" do |env|
  body = env.request.body.try &.gets_to_end
  unless body
    next json(env, {error: "Empty body"}, 400)
  end
  data = JSON.parse(body)
  name = data["name"].as_s
  kind = data["type"]?.try(&.as_s) || "Generic"
  url = data["url"]?.try(&.as_s)
  check_interval = data["checkInterval"]?.try(&.as_i) || 60
  timeout = data["timeout"]?.try(&.as_i) || 30

  db = Stem.db
  db.exec "INSERT INTO services (name, kind, url, status, avg_response_ms, last_check, check_interval_seconds, timeout_seconds) VALUES ($1, $2, $3, 'ok', 0, NOW(), $4, $5)",
    name, kind, url, check_interval, timeout

  json(env, {ok: true})
end

# Delete service
delete "/api/services/:id" do |env|
  id = env.params.url["id"].to_i64
  db = Stem.db
  db.exec "DELETE FROM services WHERE id = $1", id
  json(env, {ok: true})
end

# Logs list + filtering: /api/logs?search=&severity=&service=&limit=100
# Ingest a log (MVP)
post "/api/logs" do |env|
  body = env.request.body.try &.gets_to_end
  data = body ? JSON.parse(body) : JSON.parse("{}")
  service  = data["service"]?.try(&.as_s)
  message  = data["message"]?.try(&.as_s) || ""
  severity = data["severity"]?.try(&.as_s) || "info"

  unless service
    next json(env, {error: "service is required"}, 400)
  end

  db = Stem.db

  if sid = db.query_one? "SELECT id FROM services WHERE name = $1", service, as: Int64
    db.exec "INSERT INTO logs (service_id, message, severity) VALUES ($1, $2, $3)",
      sid, message, severity
    json(env, {ok: true})
  else
    json(env, {error: "Unknown service"}, 404)
  end
end

# Alerts list (recent, unresolved first)
get "/api/alerts" do |env|
  db = Stem.db
  alerts = [] of AlertDTO
  db.query <<-SQL do |rs|
    SELECT a.id, s.name, a.message, a.severity, a.created_at
    FROM alerts a
    JOIN services s ON s.id = a.service_id
    ORDER BY (a.resolved_at IS NULL) DESC, a.created_at DESC
    LIMIT 200
  SQL
    while rs.move_next
      id = rs.read(Int64)
      svc = rs.read(String)
      msg = rs.read(String)
      sev = rs.read(String)
      ts = rs.read(Time)
      alerts << AlertDTO.new(
        id: id,
        service: svc,
        message: msg,
        severity: sev,
        timestamp: ts.to_s("%Y-%m-%d %H:%M:%S")
      )
    end
  end

  json(env, alerts)
end

# Alert channels config (maps to your UI)
get "/api/alerts/channels" do |env|
  db = Stem.db
  channels = [] of AlertChannelDTO
  db.query "SELECT id, kind, enabled, config FROM alert_channels ORDER BY id" do |rs|
    while rs.move_next
      id = rs.read(Int64)
      kind = rs.read(String)
      enabled = rs.read(Bool)
      config = JSON.parse(rs.read(String))
      channels << AlertChannelDTO.new(
        id: id,
        name: kind.capitalize,
        enabled: enabled,
        config: config,
        icon_path: icon_for_channel(kind)
      )
    end
  end
  json(env, channels)
end

# Update a channel
put "/api/alerts/channels/:id" do |env|
  id = env.params.url["id"].to_i64
  body = env.request.body.try &.gets_to_end
  unless body
    next json(env, {error: "Empty body"}, 400)
  end
  data = JSON.parse(body)
  enabled = data["enabled"]?.try(&.as_bool)
  config = data["config"]? || JSON.parse("{}")

  db = Stem.db
  if enabled.nil?
    db.exec "UPDATE alert_channels SET config = $1::jsonb, updated_at = NOW() WHERE id = $2", config.to_json, id
  else
    db.exec "UPDATE alert_channels SET enabled = $1, config = $2::jsonb, updated_at = NOW() WHERE id = $3", enabled.as(Bool), config.to_json, id
  end
  json(env, {ok: true})
end

# Start server
# Kemal.config.logger = Kemal::BaseLogHandler#.new(STDOUT)
post "/__admin/seed" { |env| Stem.seed!; json(env, {ok: true}) }

Stem.migrate!
Stem.seed!
Kemal.config.host = "0.0.0.0"
Kemal.config.port = (ENV["PORT"]? || "3000").to_i

Kemal.run(ENV["PORT"]?.try(&.to_i) || 3000)
