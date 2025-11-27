class Service < BaseModel
  table do
    column name : String
    column kind : String
    column url : String?
    column status : String
    column avg_response_ms : Int32
    column last_check : Time?
    column check_interval_seconds : Int32
    column timeout_seconds : Int32
  end
end
