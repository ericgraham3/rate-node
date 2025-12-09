# frozen_string_literal: true

require "sqlite3"
require "singleton"

module TitleRound
  class Database
    include Singleton

    attr_reader :connection

    DEFAULT_DB_PATH = File.expand_path("../../db/title_round.db", __dir__)
    SCHEMA_PATH = File.expand_path("../../db/schema.sql", __dir__)

    def initialize
      @connection = nil
    end

    def self.setup(path = nil)
      instance.setup(path)
    end

    def self.connection
      instance.connection
    end

    def setup(path = nil)
      db_path = path || DEFAULT_DB_PATH
      @connection = SQLite3::Database.new(db_path)
      @connection.results_as_hash = true
      create_tables
      migrate_schema
      create_indexes
      self
    end

    def execute(sql, params = [])
      raise Error, "Database not initialized. Call TitleRound.setup_database first." unless @connection

      @connection.execute(sql, params)
    end

    def get_first_row(sql, params = [])
      raise Error, "Database not initialized. Call TitleRound.setup_database first." unless @connection

      @connection.get_first_row(sql, params)
    end

    private

    def create_tables
      # Create tables without indexes (indexes created separately after migration)
      tables_sql = <<-SQL
        -- Schedule of Rates (base rates for all policies)
        CREATE TABLE IF NOT EXISTS rate_tiers (
          id INTEGER PRIMARY KEY,
          min_liability_cents INTEGER NOT NULL,
          max_liability_cents INTEGER,
          base_rate_cents INTEGER NOT NULL,
          per_thousand_cents INTEGER,
          extended_lender_concurrent_cents INTEGER,
          state_code VARCHAR(2) NOT NULL DEFAULT 'CA',
          underwriter_code VARCHAR(50) NOT NULL DEFAULT 'TRG',
          effective_date DATE NOT NULL DEFAULT '2024-01-01',
          expires_date DATE
        );

        -- Refinance flat rates (1-4 family residential)
        CREATE TABLE IF NOT EXISTS refinance_rates (
          id INTEGER PRIMARY KEY,
          min_liability_cents INTEGER NOT NULL,
          max_liability_cents INTEGER,
          flat_rate_cents INTEGER NOT NULL,
          state_code VARCHAR(2) NOT NULL DEFAULT 'CA',
          underwriter_code VARCHAR(50) NOT NULL DEFAULT 'TRG',
          effective_date DATE NOT NULL DEFAULT '2024-01-01',
          expires_date DATE
        );

        -- Endorsements catalog
        CREATE TABLE IF NOT EXISTS endorsements (
          id INTEGER PRIMARY KEY,
          code VARCHAR(20) NOT NULL,
          name VARCHAR(255) NOT NULL,
          pricing_type VARCHAR(20) NOT NULL,
          base_amount_cents INTEGER,
          percentage DECIMAL(8,6),
          min_cents INTEGER,
          max_cents INTEGER,
          concurrent_discount_pct INTEGER,
          owner_only INTEGER DEFAULT 0,
          lender_only INTEGER DEFAULT 0,
          notes TEXT,
          state_code VARCHAR(2) NOT NULL DEFAULT 'CA',
          underwriter_code VARCHAR(50) NOT NULL DEFAULT 'TRG',
          effective_date DATE NOT NULL DEFAULT '2024-01-01',
          expires_date DATE
        );

        -- Policy type multipliers
        CREATE TABLE IF NOT EXISTS policy_types (
          id INTEGER PRIMARY KEY,
          name VARCHAR(50) NOT NULL,
          multiplier DECIMAL(4,2) NOT NULL,
          state_code VARCHAR(2) NOT NULL DEFAULT 'CA',
          underwriter_code VARCHAR(50) NOT NULL DEFAULT 'TRG',
          effective_date DATE NOT NULL DEFAULT '2024-01-01',
          expires_date DATE
        );
      SQL

      @connection.execute_batch(tables_sql)
    end

    def migrate_schema
      # Add jurisdiction columns to existing tables if they don't exist
      migrate_table("rate_tiers")
      migrate_table("refinance_rates")
      migrate_table("endorsements")
      migrate_table("policy_types")
    end

    def migrate_table(table_name)
      columns_to_add = {
        "rate_tiers" => [
          { name: "state_code", type: "VARCHAR(2) NOT NULL DEFAULT 'CA'", default_value: "CA" },
          { name: "underwriter_code", type: "VARCHAR(50) NOT NULL DEFAULT 'TRG'", default_value: "TRG" },
          { name: "effective_date", type: "DATE NOT NULL DEFAULT '2024-01-01'", default_value: "2024-01-01" },
          { name: "expires_date", type: "DATE", default_value: nil }
        ],
        "refinance_rates" => [
          { name: "state_code", type: "VARCHAR(2) NOT NULL DEFAULT 'CA'", default_value: "CA" },
          { name: "underwriter_code", type: "VARCHAR(50) NOT NULL DEFAULT 'TRG'", default_value: "TRG" },
          { name: "effective_date", type: "DATE NOT NULL DEFAULT '2024-01-01'", default_value: "2024-01-01" },
          { name: "expires_date", type: "DATE", default_value: nil }
        ],
        "endorsements" => [
          { name: "state_code", type: "VARCHAR(2) NOT NULL DEFAULT 'CA'", default_value: "CA" },
          { name: "underwriter_code", type: "VARCHAR(50) NOT NULL DEFAULT 'TRG'", default_value: "TRG" },
          { name: "effective_date", type: "DATE NOT NULL DEFAULT '2024-01-01'", default_value: "2024-01-01" },
          { name: "expires_date", type: "DATE", default_value: nil }
        ],
        "policy_types" => [
          { name: "state_code", type: "VARCHAR(2) NOT NULL DEFAULT 'CA'", default_value: "CA" },
          { name: "underwriter_code", type: "VARCHAR(50) NOT NULL DEFAULT 'TRG'", default_value: "TRG" },
          { name: "effective_date", type: "DATE NOT NULL DEFAULT '2024-01-01'", default_value: "2024-01-01" },
          { name: "expires_date", type: "DATE", default_value: nil }
        ]
      }

      # Check if table exists
      table_exists = @connection.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [table_name]
      ).any?

      return unless table_exists

      # Get existing columns
      existing_columns = @connection.execute("PRAGMA table_info(#{table_name})").map do |row|
        # PRAGMA returns array format: [cid, name, type, notnull, dflt_value, pk]
        row.is_a?(Hash) ? row["name"] : row[1]
      end

      columns_to_add[table_name]&.each do |column|
        next if existing_columns.include?(column[:name])

        begin
          @connection.execute(
            "ALTER TABLE #{table_name} ADD COLUMN #{column[:name]} #{column[:type]}"
          )

          # Update existing rows with default values
          if column[:default_value]
            @connection.execute(
              "UPDATE #{table_name} SET #{column[:name]} = ? WHERE #{column[:name]} IS NULL",
              [column[:default_value]]
            )
          end
        rescue SQLite3::SQLException => e
          # Ignore if column already exists (shouldn't happen, but be safe)
          raise e unless e.message.include?("duplicate column")
        end
      end
    end

    def create_indexes
      # Drop old unique index on endorsements if it exists
      begin
        @connection.execute("DROP INDEX IF EXISTS idx_endorsements_code")
      rescue SQLite3::SQLException
        # Ignore if index doesn't exist
      end

      # Create all indexes
      indexes = [
        "CREATE INDEX IF NOT EXISTS idx_rate_tiers_liability ON rate_tiers(min_liability_cents, max_liability_cents)",
        "CREATE INDEX IF NOT EXISTS idx_rate_tiers_jurisdiction ON rate_tiers(state_code, underwriter_code, effective_date)",
        "CREATE INDEX IF NOT EXISTS idx_refinance_rates_liability ON refinance_rates(min_liability_cents, max_liability_cents)",
        "CREATE INDEX IF NOT EXISTS idx_refinance_rates_jurisdiction ON refinance_rates(state_code, underwriter_code, effective_date)",
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_endorsements_code_jurisdiction ON endorsements(code, state_code, underwriter_code, effective_date)",
        "CREATE INDEX IF NOT EXISTS idx_endorsements_jurisdiction ON endorsements(state_code, underwriter_code, effective_date)",
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_policy_types_unique ON policy_types(name, state_code, underwriter_code, effective_date)",
        "CREATE INDEX IF NOT EXISTS idx_policy_types_jurisdiction ON policy_types(state_code, underwriter_code, effective_date)"
      ]

      indexes.each do |index_sql|
        begin
          @connection.execute(index_sql)
        rescue SQLite3::SQLException => e
          # Ignore errors for indexes that already exist or columns that don't exist yet
          raise e unless e.message.include?("already exists") || e.message.include?("no such column")
        end
      end
    end
  end
end
