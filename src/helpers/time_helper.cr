module TimeHelper
  def self.time_ago(ts : Time?) : String
    return "—" unless ts
    diff = Time.utc - ts
    mins = diff.total_minutes.to_i
    return "#{mins} min ago" if mins < 60
    hours = diff.total_hours.to_i
    return "#{hours} hour ago" if hours == 1
    return "#{hours} hours ago" if hours < 24
    days = diff.total_days.to_i
    days == 1 ? "1 day ago" : "#{days} days ago"
  end
end
