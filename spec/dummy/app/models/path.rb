class Path < ActiveRecord::Base
  self.table_name = 'traffic.paths' if ENV['LOOKUP_BY_DB_ADAPTER'] != 'mysql2'
  self.table_name = 'paths' if ENV['LOOKUP_BY_DB_ADAPTER'] == 'mysql2'

  lookup_by :path, cache: 40, find_or_create: true
end
