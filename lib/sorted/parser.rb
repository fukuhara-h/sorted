require 'sorted/toggler'

module Sorted
  # Takes a sort query string and an SQL order string and parses the
  # values to produce key value pairs.
  #
  # Example:
  #  Sorted::Parser.new('phone_desc', 'name ASC').to_s #-> "phone_desc!name_asc"
  class Parser
    attr_reader :sort, :order, :sorts, :orders

    # Regex to make sure we only get valid names and not injected code.
    SORTED_QUERY_REGEX  = /([a-zA-Z0-9._]+)_(asc|desc)$/
    SQL_REGEX           = /(([a-z0-9._]+)\s([asc|desc]+)|[a-z0-9._]+)/i

    def initialize(sort, order = nil, whitelist = [])
      @sort      = sort
      @order     = order
      @sorts     = parse_sort
      @orders    = parse_order
      @whitelist = Parser::initialize_whitelist whitelist
    end

    def parse_sort
      sort.to_s.split(/!/).map do |sort_string|
        if m = sort_string.match(SORTED_QUERY_REGEX)
          [m[1], m[2].downcase]
        end
      end.compact
    end

    def parse_order
      order.to_s.split(/,/).map do |order_string|
        if m = order_string.match(SQL_REGEX)
          [(m[2].nil? ? m[1] : m[2]),(m[3].nil? ? "asc" : m[3].downcase)]
        end
      end.compact
    end

    def to_hash
      array.inject({}){|h,a| h.merge(Hash[a[0],a[1]])}
    end

    def to_sql(quoter = ->(frag) { frag })
      array.map do |a|
        column = a[0].split('.').map{ |frag| quoter.call(frag) }.join('.')
        "#{column} #{a[1].upcase}"
      end.join(', ')
    end

    def to_s
      array.map{|a| a.join('_') }.join('!')
    end

    def to_a
      array
    end

    def toggle
      @array = apply_whitelist Toggler.new(sorts, orders).to_a
      self
    end

    def reset
      @array = default
      self
    end

    private

    def self.initialize_whitelist(arg)
      return nil if arg.nil?
      list =
        if arg.respond_to?(:to_ary)
          arg.to_ary || [arg]
        else
          [arg]
        end

      list.flatten.map do |item|
        case
        when item.is_a?(String)
          [item]
        when %i(table_name column_names).all? { |m| item.respond_to? m }
          item.column_names.map { |c| "#{item.table_name}.#{c}" }
        end
      end.compact.flatten(1)
    end

    def apply_whitelist(arr)
      return arr if @whitelist.nil?
      arr.select do |field, dir|
        @whitelist.include?(field) && ["asc", "desc"].include?(dir)
      end
    end

    def array
      @array ||= default
    end

    def default
      sorts_new = sorts.dup
      orders.each do |o|
        sorts_new << o unless sorts_new.flatten.include?(o[0])
      end
      apply_whitelist sorts_new
    end
  end
end
