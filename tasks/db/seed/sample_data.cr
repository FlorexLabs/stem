require "../../../spec/support/factories/**"

# Add sample data helpful for development, e.g. (fake users, blog posts, etc.)
#
# Use `Db::Seed::RequiredData` if you need to create data *required* for your
# app to work.
class Db::Seed::SampleData < LuckyTask::Task
  summary "Add sample database records helpful for development"

  def call
    return if ServiceQuery.new.select_count > 0

    now = Time.utc

    services = [
      {name: "rails-api", kind: "Rails", url: "https://api.example.com", status: "ok", avg: 145, last_check_min: 2},
      {name: "node-worker", kind: "Node.js", url: "https://worker.example.com", status: "ok", avg: 89, last_check_min: 1},
      {name: "auth-service", kind: "Rails", url: "https://auth.example.com", status: "warning", avg: 312, last_check_min: 3},
      {name: "websocket-server", kind: "Node.js", url: "wss://ws.example.com", status: "ok", avg: 52, last_check_min: 1},
      {name: "payment-gateway", kind: "Rails", url: "https://pay.example.com", status: "ok", avg: 198, last_check_min: 2},
      {name: "email-processor", kind: "Node.js", url: "https://mail.example.com", status: "error", avg: 0, last_check_min: 5},
    ]

    services.each do |s|
      op = Service::SaveOperation.new
      op.name.value = s[:name]
      op.kind.value = s[:kind]
      op.url.value = s[:url]
      op.status.value = s[:status]
      op.avg_response_ms.value = s[:avg]
      op.last_check.value = now - s[:last_check_min].minutes
      op.check_interval_seconds.value = 60
      op.timeout_seconds.value = 30
      op.save!
    end

    puts "Done adding sample data"
  end
end
