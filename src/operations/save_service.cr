class SaveService < Service::SaveOperation
  # To save user provided params to the database, you must permit them
  # https://luckyframework.org/guides/database/saving-records#perma-permitting-columns
  #
  # permit_columns name, kind, url, status, avg_response_ms, last_check, check_interval_seconds, timeout_seconds
end
