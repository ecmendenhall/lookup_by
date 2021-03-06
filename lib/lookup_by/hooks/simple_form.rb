require "active_support/concern"

module LookupBy
  module Hooks
    module SimpleForm
      extend ActiveSupport::Concern

      included do
        alias_method_chain :input, :lookup
      end

      def input_with_lookup(method, options = {}, &block)
        klass = object.class

        if klass.respond_to?(:lookups) && klass.lookups.include?(method.to_sym)
          target = method.to_s.classify.constantize

          options[:collection] ||= target.pluck(target.lookup.field) if target.lookup.cache_all?
        end

        input_without_lookup(method, options, &block)
      end
    end
  end
end

::SimpleForm::FormBuilder.send :include, LookupBy::Hooks::SimpleForm
