class CreateServices::V20251127131707 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(Service) do
      primary_key id : Int64

      add name : String
      add kind : String
      add url : String?

      add status : String, default: "ok"
      add avg_response_ms : Int32, default: 0
      add last_check : Time?

      add check_interval_seconds : Int32, default: 60
      add timeout_seconds : Int32, default: 30

      add_timestamps

      add_index :name, unique: true
    end
  end

  def rollback
    drop table_for(Service)
  end
end
