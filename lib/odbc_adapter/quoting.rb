module ODBCAdapter
  module Quoting
    extend ActiveSupport::Concern

    # Shared quoting logic that works without database metadata
    def self.quote_identifier(name, quote_char = '"', upcase_identifiers = false)
      name = name.to_s
      
      # If already fully quoted, return as-is
      return name if name.include?(quote_char) && name.start_with?(quote_char) && name.end_with?(quote_char)
      
      # If it contains a dot (schema.table or table.column), handle each part
      if name.include?('.')
        parts = name.split('.')
        return parts.map { |part| 
          part.strip.start_with?(quote_char) && part.strip.end_with?(quote_char) ? part : quote_identifier(part, quote_char, upcase_identifiers)
        }.join('.')
      end
      
      # For simple column names (like those from alias_attribute resolution),
      # if they look like database column names (lowercase, no spaces), don't quote them
      # This handles Rails 8's resolved column names from alias_attribute
      return name if name.match?(/\A[a-z][a-z0-9_]*\z/)
      
      # If upcase identifiers, only quote mixed case names
      if upcase_identifiers
        return name unless name =~ /([A-Z]+[a-z])|([a-z]+[A-Z])/
      end
      
      "#{quote_char}#{name}#{quote_char}"
    end

    # Instance methods (backwards compatibility)
    included do
      # Quotes a string, escaping any ' (single quote) characters.
      def quote_string(string)
        string.gsub(/\'/, "''")
      end

      # Returns a quoted form of the column name using database metadata.
      def quote_column_name(name)
        quote_char = database_metadata.identifier_quote_char.to_s.strip
        quote_char = quote_char.empty? ? '"' : quote_char[0]
        upcase_identifiers = database_metadata.upcase_identifiers?
        
        ODBCAdapter::Quoting.quote_identifier(name, quote_char, upcase_identifiers)
      end

      # Ideally, we'd return an ODBC date or timestamp literal escape
      # sequence, but not all ODBC drivers support them.
      def quoted_date(value)
        if value.acts_like?(:time)
          zone_conversion_method = ActiveRecord.default_timezone == :utc ? :getutc : :getlocal

          if value.respond_to?(zone_conversion_method)
            value = value.send(zone_conversion_method)
          end
          value.strftime('%Y-%m-%d %H:%M:%S') # Time, DateTime
        else
          value.strftime('%Y-%m-%d') # Date
        end
      end
    end

    # Class methods for Rails 8 compatibility
    class_methods do
      def quote_column_name(name)
        # Class methods don't have access to database metadata, so use sensible defaults
        # Most ODBC drivers use double quotes, and most don't require upcase identifier handling
        ODBCAdapter::Quoting.quote_identifier(name, '"', false)
      end

      def quote_table_name(name)
        quote_column_name(name)
      end
    end
  end
end
