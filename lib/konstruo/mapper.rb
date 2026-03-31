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

      sig do
        params(
          name:          Symbol,
          type:          FieldType,
          required:      T::Boolean,
          custom_name:   T.nilable(String),
          mapper:        T.nilable(T.proc.params(value: T.untyped).returns(T.untyped)),
          error_message: T.nilable(String)
        ).void
      end
      def field(name, type, required: false, custom_name: nil, mapper: nil, error_message: nil)
        attr_accessor name unless method_defined?(name)

        validate_field_type!(type)

        fields << FieldDefinition.new(
          name:          name,
          type:          type,
          required:      required,
          custom_name:   custom_name || name.to_s,
          mapper:        mapper,
          error_message: error_message
        )
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
    end

    sig { params(hash: InputHash).returns(T.self_type) }
    def from_hash(hash)
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
          raise Konstruo::ValidationError, (field.error_message || "Missing required field: #{key}") if field.required
        else
          assign_value(field.name, field.type, value, field.mapper, field.error_message)
        end
      end

      self
    end

    private

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

            element_type.new.from_hash(element)
          else
            validate_type!(element, element_type, "#{field_name}[#{index}]", error_message)
            element
          end
        end

        send(:"#{field_name}=", validated_array)
      elsif field_type < Konstruo::Mapper
        raise Konstruo::ValidationError, (error_message || "Expected Hash for field: #{field_name}, got #{value.class}") unless value.is_a?(Hash)

        send(:"#{field_name}=", field_type.new.from_hash(value))
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
  end
end
