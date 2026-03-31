# typed: strict
# frozen_string_literal: true

require 'konstruo/mapper'

class Address < Konstruo::Mapper
  field :street, String, required: true, error_message: 'Street is required.'
  field :city, String, required: true
end

class Person < Konstruo::Mapper
  field :name, String, required: true, error_message: 'You must provide a name.'
  field :age, Integer
  field :email, String
  field :address, Address, required: true
  field :addresses, [Address], required: true
  field :user_id, Integer, required: true, custom_name: 'userId'
  field :signup_date, Date, required: true, custom_name: 'signupDate', mapper: ->(v) { Date.parse(v) }
  field :friends, [String], required: false
  field :is_active, Konstruo::Boolean, required: true
end

class InvalidFieldDefinitionMapper < Konstruo::Mapper
end

class InheritanceBaseMapper < Konstruo::Mapper
  field :id, Integer, required: true
end

class InheritanceChildMapper < InheritanceBaseMapper
  field :name, String, required: true
end

class StrictPersonMapper < Konstruo::Mapper
  strict_unknown_keys
  field :name, String, required: true
end

class LoosePersonMapper < Konstruo::Mapper
  field :name, String, required: true
end
