# frozen_string_literal: true

module Mongory
  module Converters
    # KeyConverter handles transformation of field keys in query conditions.
    # It normalizes symbol keys into string paths, splits dotted keys,
    # and delegates to the appropriate converter logic.
    #
    # This class inherits from AbstractConverter and registers rules for
    # strings, symbols, and includes a fallback handler.
    # Used by ConditionConverter to build query structures from flat input.
    #
    # - `"a.b.c" => v` becomes `{ "a" => { "b" => { "c" => v } } }`
    # - Symbols are stringified and delegated to String logic
    # - QueryOperator dispatches to internal DSL hook
    #
    # @example Convert a dotted string key
    #   KeyConverter.instance.convert("user.name") #=> { "user" => { "name" => value } }
    #
    class KeyConverter < AbstractConverter
      # fallback if key type is unknown — returns { self => value }
      def initialize
        super
        @fallback = ->(x) { { self => x } }
      end

      def default_registrations
        convert_string_key = method(:convert_string_key)
        register(String) do |value|
          convert_string_key.call(self, value)
        end

        # - `:"a.b.c" => v` becomes `{ "a" => { "b" => { "c" => v } } }`
        register(Symbol) do |other|
          convert_string_key.call(to_s, other)
        end

        # - `:"a.b.c".present => true` becomes `{ "a" => { "b" => { "c" => { "$present" => true } } } }`
        register(QueryOperator, :__expr_part__)
      end

      # Converts a dotted string key into nested hash form.
      #
      # @param key [String] the dotted key string, e.g. "a.b.c"
      # @param value [Object] the value to assign at the deepest level
      # @return [Hash] nested hash structure
      def convert_string_key(key, value)
        ret = {}
        *sub_keys, last_key = key.split(/(?<!\\)\./)
        last_hash = sub_keys.reduce(ret) do |res, sub_key|
          next_res = res[normalize_key(sub_key)] = {}
          next_res
        end
        last_hash[normalize_key(last_key)] = value
        ret
      end

      def normalize_key(key)
        key.gsub(/\\\./, '.')
      end
    end
  end
end
