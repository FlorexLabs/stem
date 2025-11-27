class ServiceSerializer < BaseSerializer
  def initialize(@service : Service); end

  def render
    {
      id:           @service.id,
      name:         @service.name,
      type:         @service.kind,
      status:       @service.status,
      responseTime: @service.avg_response_ms,
      lastCheck:    TimeHelper.time_ago(@service.last_check),
      sparkline:    [] of Int32,
    }
  end
end
