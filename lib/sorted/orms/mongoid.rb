require 'sorted'
require 'active_support/concern'

module Sorted
  module Orms
    module Mongoid
      extend ActiveSupport::Concern
      SQL_TO_MONGO = { "asc" => 1, "desc" => -1 }

      included do
        def self.sorted(sort, default_order = nil, whitelist = [])
          sorter = ::Sorted::Parser.new(sort, default_order, whitelist)
          order_by sorter.to_hash.merge(sorter) { |key, val| SQL_TO_MONGO[val] }
        end
      end
    end
  end
end
