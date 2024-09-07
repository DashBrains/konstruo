# typed: strict
# frozen_string_literal: true

require 'active_support/all'
require 'action_controller'

module Konstruo
  class Mapper
    extend T::Sig

    # Class variable to store field definitions
    @fields = T.let([], T::Array[T::Hash[Symbol, T.untyped]])

    class << self
      extend T::Sig

      sig { returns(T::Array[T::Hash[Symbol, T.untyped]]) }
      attr_reader :fields
    end

    sig do
      params(name: Symbol, type: T.any(T.class_of(Object), T::Array[T.class_of(Object)]), required: T::Boolean,
             custom_name: T.nilable(String), mapper: T.nilable(T.proc.params(value: T.untyped).returns(T.untyped)),
             error_message: T.nilable(String)).void
    end
    def self.field(name, type, required: false, custom_name: nil, mapper: nil, error_message: nil)
      # Check if the attribute is already defined
      attr_accessor name unless method_defined?(name)

      @fields ||= [] if @fields.nil?
      @fields << { name:, type:, required:, custom_name: custom_name || name.to_s, mapper:, error_message: }
    end

    sig { params(json_string: String).returns(T.attached_class) }
    def self.from_json(json_string)
      hash = JSON.parse(json_string)
      new.from_hash(hash)
    end

    sig { params(params: ActionController::Parameters).returns(T.attached_class) }
    def self.from_params(params)
      hash = params.to_unsafe_h
      new.from_hash(hash)
    end

    sig { params(hash: T::Hash[Symbol, T.untyped]).returns(T.attached_class) }
    def self.from_hash(hash)
      new.from_hash(hash)
    end

    sig { params(hash: T::Hash[Symbol, T.untyped]).returns(T.self_type) }
    def from_hash(hash)
      self.class.fields.each do |field|
        key = field[:custom_name]
        value = hash[key.to_s] || hash[key.to_sym]

        if value.nil?
          raise Konstruo::ValidationError, (field[:error_message] || "Missing required field: #{key}") if field[:required]
        else
          assign_value(field[:name], field[:type], value, field[:mapper], field[:error_message])
        end
      end
      self
    end

    private

    sig do
      params(field_name: Symbol, field_type: T.any(T.class_of(Object), T::Array[T.class_of(Object)]), value: T.untyped, mapper: T.nilable(T.proc.params(value: T.untyped).returns(T.untyped)),
             error_message: T.nilable(String)).void
    end
    def assign_value(field_name, field_type, value, mapper = nil, error_message = nil)
      value = mapper.call(value) if mapper

      if field_type.is_a?(Array)
        # Check if the value is an array
        raise Konstruo::ValidationError, (error_message || "Expected Array for field: #{field_name}, got #{value.class}") unless value.is_a?(Array)

        # Validate each element in the array
        element_type = field_type.first

        validated_array = value.map.with_index do |element, index|
          if T.must(element_type) < Konstruo::Mapper
            # If it's a nested AutoMapper object, recursively map it
            T.cast(element_type, T.class_of(Konstruo::Mapper)).new.from_hash(element)
          else
            # Validate individual element types
            validate_type!(element, T.must(element_type), "#{field_name}[#{index}]", error_message)
            element
          end
        end

        send(:"#{field_name}=", validated_array)
      elsif field_type < Konstruo::Mapper
        send(:"#{field_name}=", field_type.new.from_hash(value))
      else
        validate_type!(value, field_type, field_name, error_message)
        send(:"#{field_name}=", value)
      end
    end

    sig do
      params(
        value:         T.untyped,
        expected_type: T.any(T.class_of(Object), T::Array[T.class_of(Object)]),
        field_name:    T.any(Symbol, String),
        error_message: T.nilable(String)
      ).void
    end
    def validate_type!(value, expected_type, field_name, error_message = nil)
      # Custom handling for Boolean type
      if expected_type == Konstruo::Boolean
        raise Konstruo::ValidationError, (error_message || "Expected Boolean for field: #{field_name}, got #{value.class}") unless value.is_a?(TrueClass) || value.is_a?(FalseClass)
      else
        # Fallback to is_a? for runtime type checking if Sorbet is not available
        raise Konstruo::ValidationError, (error_message || "Expected #{expected_type} for field: #{field_name}, got #{value.class}") unless value.is_a?(expected_type)
      end
    end
  end
end
