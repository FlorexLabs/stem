module OperationErrorHelpers
  # Works with Avram::Operation#errors (Hash(Symbol, Array(String)))
  def full_messages : Array(String)
    errors.flat_map do |attr, messages|
      messages.map do |msg|
        # Turn `:name` + "is required" into "name is required"
        "#{attr} #{msg}"
      end
    end
  end
end
