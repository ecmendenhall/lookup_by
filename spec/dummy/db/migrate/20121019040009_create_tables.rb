class CreateTables < ActiveRecord::Migration
  def up
    create_lookup_tables :cities, :states, :postal_codes, :streets, :countries

    create_lookup_table :user_agents
    create_lookup_table :email_addresses


    create_lookup_table :statuses, small: true

    create_lookup_table :ip_addresses, lookup_type: :string

    create_lookup_table :phone_numbers

    create_lookup_table :uncacheables
    create_lookup_table :unfindables

    create_lookup_table :raisins
    create_lookup_table :read_through_raisins

    create_lookup_table :unsynchronizables

    if ENV['LOOKUP_BY_DB_ADAPTER'] != 'mysql2'
      enable_extension 'uuid-ossp'
      execute 'CREATE SCHEMA traffic;'
      create_lookup_table :paths, schema: 'traffic', id: :uuid
    else
      create_table :traffic
      create_lookup_table :paths
    end

    create_lookup_table :accounts do |t|
      t.belongs_to :phone_number
    end

    create_lookup_table :addresses do |t|
      t.belongs_to :city
      t.belongs_to :state
      t.belongs_to :postal_code
      t.belongs_to :street
      t.belongs_to :country
    end
  end
end
