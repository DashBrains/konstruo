# typed: strict
# frozen_string_literal: true

require 'active_support/all'
require 'action_controller'

module Konstruo
  class Mapper
    extend T::Sig

    FieldClass = T.type_alias { T.class_of(Object) }
    FieldType = T.type_alias { T.any(FieldClass, T::Array[FieldClass]) }
    InputHash = T.type_alias { T::Hash[T.any(String, Symbol), T.untyped] }

    class FieldDefinition < T::Struct
      const :name, Symbol
      const :type, FieldType
      const :required, T::Boolean
      const :nullable, T::Boolean
      const :custom_name, String
      const :mapper, T.nilable(T.proc.params(value: T.untyped).returns(T.untyped))
      const :error_message, T.nilable(String)
    end

    class << self
      extend T::Sig

      sig { returns(T::Array[FieldDefinition]) }
      def fields
        existing = T.let(T.unsafe(self).instance_variable_get(:@fields), T.nilable(T::Array[FieldDefinition]))
        return existing unless existing.nil?

        initialized = T.let([], T::Array[FieldDefinition])
        T.unsafe(self).instance_variable_set(:@fields, initialized)
        initialized
      end

      sig { returns(T::Array[T.class_of(::Konstruo::Mapper)]) }
      def descendants
        existing = T.let(
          T.unsafe(self).instance_variable_get(:@descendants),
          T.nilable(T::Array[T.class_of(::Konstruo::Mapper)])
        )
        return existing unless existing.nil?

        initialized = T.let([], T::Array[T.class_of(::Konstruo::Mapper)])
        T.unsafe(self).instance_variable_set(:@descendants, initialized)
        initialized
      end

      sig do
        params(
          name:          Symbol,
          type:          FieldType,
          required:      T::Boolean,
          nullable:      T.nilable(T::Boolean),
          custom_name:   T.nilable(String),
          mapper:        T.nilable(T.proc.params(value: T.untyped).returns(T.untyped)),
          error_message: T.nilable(String)
        ).void
      end
      def field(name, type, required: false, nullable: nil, custom_name: nil, mapper: nil, error_message: nil)
        attr_accessor name unless method_defined?(name)

        validate_field_type!(type)
        resolved_nullable = nullable.nil? ? !required : nullable

        fields << FieldDefinition.new(
          name:          name,
          type:          type,
          required:      required,
          nullable:      resolved_nullable,
          custom_name:   custom_name || name.to_s,
          mapper:        mapper,
          error_message: error_message
        )
      end

      sig { params(value: T::Boolean).void }
      def strict_unknown_keys(value = true)
        T.unsafe(self).instance_variable_set(:@strict_unknown_keys, value)
      end

      sig { returns(T::Boolean) }
      def strict_unknown_keys?
        value = T.let(T.unsafe(self).instance_variable_get(:@strict_unknown_keys), T.nilable(T::Boolean))
        value == true
      end

      sig { params(subclass: T.class_of(Konstruo::Mapper)).void }
      def inherited(subclass)
        super
        subclass.instance_variable_set(:@fields, fields.dup)
        subclass.instance_variable_set(:@strict_unknown_keys, strict_unknown_keys?)
        ::Konstruo::Mapper.send(:register_descendant, subclass)
      end

      sig { params(json_string: String).returns(T.attached_class) }
      def from_json(json_string)
        parsed = JSON.parse(json_string)
        raise Konstruo::ValidationError, 'Expected JSON object at root' unless parsed.is_a?(Hash)

        new.from_hash(parsed)
      end

      sig { params(params: ActionController::Parameters).returns(T.attached_class) }
      def from_params(params)
        new.from_hash(params.to_unsafe_h)
      end

      sig { params(hash: InputHash).returns(T.attached_class) }
      def from_hash(hash)
        new.from_hash(hash)
      end

      private

      sig { params(type: FieldType).void }
      def validate_field_type!(type)
        return unless type.is_a?(Array)
        return if type.size == 1 && type.first.is_a?(Class)

        raise ArgumentError, 'Array field type must contain exactly one class'
      end

      sig { params(subclass: T.class_of(::Konstruo::Mapper)).void }
      def register_descendant(subclass)
        root = ::Konstruo::Mapper
        list = root.descendants
        list << subclass unless list.include?(subclass)
      end
    end

    sig { params(hash: InputHash).returns(T.self_type) }
    def from_hash(hash)
      validate_unknown_keys!(hash) if self.class.strict_unknown_keys?

      self.class.fields.each do |field|
        key = field.custom_name
        symbol_key = key.to_sym
        has_string_key = hash.key?(key)
        has_symbol_key = hash.key?(symbol_key)

        unless has_string_key || has_symbol_key
          raise Konstruo::ValidationError, (field.error_message || "Missing required field: #{key}") if field.required

          next
        end

        value = has_string_key ? hash[key] : hash[symbol_key]

        if value.nil?
          raise Konstruo::ValidationError, (field.error_message || "Field cannot be nil: #{key}") unless field.nullable

          send(:"#{field.name}=", nil)
        else
          assign_value(field.name, field.type, value, field.mapper, field.error_message)
        end
      end

      self
    end

    private

    sig { params(hash: InputHash).void }
    def validate_unknown_keys!(hash)
      allowed_keys = Set.new(self.class.fields.map(&:custom_name))
      unknown_keys = hash.keys.map(&:to_s).reject { |key| allowed_keys.include?(key) }.uniq.sort
      return if unknown_keys.empty?

      raise Konstruo::ValidationError, "Unknown fields: #{unknown_keys.join(", ")}"
    end

    sig do
      params(
        field_name:    Symbol,
        field_type:    FieldType,
        value:         T.untyped,
        mapper:        T.nilable(T.proc.params(value: T.untyped).returns(T.untyped)),
        error_message: T.nilable(String)
      ).void
    end
    def assign_value(field_name, field_type, value, mapper = nil, error_message = nil)
      value = mapper.call(value) if mapper

      if field_type.is_a?(Array)
        raise Konstruo::ValidationError, (error_message || "Expected Array for field: #{field_name}, got #{value.class}") unless value.is_a?(Array)

        element_type = T.must(field_type.first)

        validated_array = value.map.with_index do |element, index|
          if element_type < Konstruo::Mapper
            unless element.is_a?(Hash)
              raise Konstruo::ValidationError, (error_message || "Expected Hash for field: #{field_name}[#{index}], got #{element.class}")
            end

            begin
              element_type.new.from_hash(element)
            rescue Konstruo::ValidationError => e
              raise Konstruo::ValidationError, prefix_nested_error(e.message, "#{field_name}[#{index}]")
            end
          else
            validate_type!(element, element_type, "#{field_name}[#{index}]", error_message)
            element
          end
        end

        send(:"#{field_name}=", validated_array)
      elsif field_type < Konstruo::Mapper
        raise Konstruo::ValidationError, (error_message || "Expected Hash for field: #{field_name}, got #{value.class}") unless value.is_a?(Hash)

        mapped_value = begin
          field_type.new.from_hash(value)
        rescue Konstruo::ValidationError => e
          raise Konstruo::ValidationError, prefix_nested_error(e.message, field_name.to_s)
        end
        send(:"#{field_name}=", mapped_value)
      else
        validate_type!(value, field_type, field_name, error_message)
        send(:"#{field_name}=", value)
      end
    end

    sig do
      params(
        value:         T.untyped,
        expected_type: FieldClass,
        field_name:    T.any(Symbol, String),
        error_message: T.nilable(String)
      ).void
    end
    def validate_type!(value, expected_type, field_name, error_message = nil)
      if expected_type == Konstruo::Boolean
        unless Konstruo::Boolean.boolean?(value)
          raise Konstruo::ValidationError, (error_message || "Expected Boolean for field: #{field_name}, got #{value.class}")
        end
      else
        unless value.is_a?(expected_type)
          raise Konstruo::ValidationError, (error_message || "Expected #{expected_type} for field: #{field_name}, got #{value.class}")
        end
      end
    end

    sig { params(message: String, prefix: String).returns(String) }
    def prefix_nested_error(message, prefix)
      missing_field_match = message.match(/\AMissing required field: (.+)\z/)
      if missing_field_match
        return "Missing required field: #{prefix}.#{T.must(missing_field_match[1])}"
      end

      type_error_match = message.match(/\AExpected (.+) for field: (.+), got (.+)\z/)
      if type_error_match
        expected = T.must(type_error_match[1])
        field_path = T.must(type_error_match[2])
        actual = T.must(type_error_match[3])
        return "Expected #{expected} for field: #{prefix}.#{field_path}, got #{actual}"
      end

      "#{prefix}: #{message}"
    end
  end
end
