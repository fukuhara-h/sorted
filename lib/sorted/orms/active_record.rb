require 'sorted'
require 'active_support/concern'

module Sorted
  module Orms
    module ActiveRecord
      extend ActiveSupport::Concern

      included do
        def self.sorted(sort, default_order = nil, whitelist = [], customlist = {})
          sorter = ::Sorted::Parser.new(sort, default_order, whitelist, customlist, -> (msg) { logger.debug msg })
          quoter = ->(frag) { connection.quote_column_name(frag) }
          order sorter.to_sql(quoter)
        end
      end
    end
  end
end
