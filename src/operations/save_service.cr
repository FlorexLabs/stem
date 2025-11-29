class SaveService < Service::SaveOperation
  include OperationErrorHelpers

  permit_columns name, kind, url, check_interval_seconds, timeout_seconds

  before_save do
    status.value ||= "ok"
    avg_response_ms.value ||= 0
    last_check.value ||= Time.utc

    validate_required name
  end
end
