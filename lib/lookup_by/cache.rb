module LookupBy
  class Cache
    attr_reader   :cache, :field, :stats
    attr_accessor :testing

    def initialize(klass, options = {})
      @klass            = klass
      @primary_key      = klass.primary_key
      @primary_key_type = klass.columns_hash[@primary_key].type
      @field            = options[:field].to_sym
      @cache            = {}
      @reverse          = {}
      @order            = options[:order] || @field
      @read             = options[:find_or_create] || options[:find]
      @write            = options[:find_or_create]
      @allow_blank      = options[:allow_blank] || false
      @normalize        = options[:normalize]
      @raise_on_miss    = options[:raise] || false
      @testing          = false
      @enabled          = true
      @safe             = options[:safe] || concurrent?
      @mutex            = Mutex.new if @safe

      @stats            = { db: Hash.new(0), cache: Hash.new(0) }

      raise ArgumentError, %Q(unknown attribute "#{@field}" for <#{klass}>) unless klass.column_names.include?(@field.to_s)

      # Order matters here, some instance variables depend on prior assignments.
      case options[:cache]
      when true
        @type    = :all
        @read  ||= false

        raise ArgumentError, "`#{@klass}.lookup_by :#{@field}` Should be `cache: true` or `cache: N, find_or_create: true`" if @write
      when ::Integer
        raise ArgumentError, "`#{@klass}.lookup_by :#{@field}` options[:find] must be true when caching N" if @read == false

        @type    = :lru
        @limit   = options[:cache]
        @cache   = @safe ? Caching::SafeLRU.new(@limit) : Caching::LRU.new(@limit)
        @reverse = @safe ? Caching::SafeLRU.new(@limit) : Caching::LRU.new(@limit)
        @read    = true
        @write ||= false
        @testing = true if Rails.env.test? && @write
      else
        @read    = true
      end

      if @write && @raise_on_miss
        raise ArgumentError, "`#{@klass}.lookup_by :#{@field}` can not use `raise: true` and `find_or_create: true` together."
      end
    end

    def reload
      return unless @type == :all

      clear

      ::ActiveRecord::Base.connection.send :log, "", "#{@klass.name} Load Cache All" do
        @klass.order(@order).each do |object|
          cache_write(object)
        end
      end
    end

    def clear
      @cache.clear
    end

    def create(*args, &block)
      created = @klass.create(*args, &block)

      cache_write(created) if cache?

      created
    end

    def create!(*args, &block)
      created = @klass.create!(*args, &block)

      cache_write(created) if cache?

      created
    end

    def seed(*values)
      @klass.transaction(requires_new: true) do
        values.map { |value| @klass.where(@field => value).first_or_create! }
      end
    end

    def fetch(value)
      increment :cache, :get

      value = normalize(value)  if @normalize && !primary_key?(value)

      found = cache_read(value) if cache?
      found ||= db_read(value)  if @read || !@enabled

      cache_write(found) if cache?

      found ||= db_write(value) if @write

      if @raise_on_miss && found.nil?
        raise LookupBy::RecordNotFound, "No #{@klass.name} lookup record found for value: #{value.inspect}"
      end

      found
    end

    def has_cache?
      @type && @enabled
    end

    def read_through?
      @read
    end

    def allow_blank?
      @allow_blank
    end

    def enabled?
      @enabled
    end

    def disabled?
      !@enabled
    end

    def enable!
      @enabled = true
      reload
    end

    def disable!
      @enabled = false
      clear
    end

  private

    # RAILS_ENV=test will not use the SafeLRU
    def concurrent?
      Rails.configuration.cache_classes && Rails.configuration.eager_load
    end

    def primary_key?(value)
      case @primary_key_type
      when :integer
        value.is_a? Integer
      when :uuid, :string
        value =~ UUID_REGEX
      end
    end

    def normalize(value)
      @klass.new(@field => value).send(@field)
    end


    if Rails.env.production?
      def cache_read(value)
        if primary_key?(value)
          @cache[value]
        else
          @reverse[value]
        end
      end
    else
      def cache_read(value)
        found = if primary_key?(value)
          @cache[value]
        else
          @reverse[value]
        end

        increment :cache, found ? :hit : :miss

        found
      end
    end

    if Rails.env.production?
      def db_read(value)
        @klass.where(column_for(value) => value).first
      end
    else
      def db_read(value)
        increment :db, :get

        found = @klass.where(column_for(value) => value).first

        increment :db, found ? :hit : :miss

        found
      end
    end

    if @safe
      def cache_write(object)
        return unless object

        @mutex.synchronize do
          @reverse[object.send(@field)] = @cache[object.id] = object
        end
      end
    else
      def cache_write(object)
        return unless object

        @reverse[object.send(@field)] = @cache[object.id] = object
      end
    end

    def db_write(value)
      column = column_for(value)

      return if column == @primary_key

      @klass.transaction(requires_new: true) do
        @klass.create(column => value)
      end
    rescue ActiveRecord::RecordNotUnique
      db_read(value)
    end

    def column_for(value)
      primary_key?(value) ? @primary_key : @field
    end

    def cache?
      @type && @enabled && !@testing
    end

    def increment(type, stat)
      @stats[type][stat] += 1
    end
  end
end
