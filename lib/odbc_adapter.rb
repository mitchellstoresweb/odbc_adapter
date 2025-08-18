# Requiring with this pattern to mirror ActiveRecord
require 'active_record/connection_adapters/odbc_adapter'

# Register the ODBC adapter with ActiveRecord
class Railtie < Rails::Railtie
  initializer "odbc_adapter.configure" do |app|
    ActiveRecord::ConnectionAdapters.register(
      "odbc", 
      "ActiveRecord::ConnectionAdapters::ODBCAdapter", 
      "active_record/connection_adapters/odbc_adapter.rb"
    )
  end
end
