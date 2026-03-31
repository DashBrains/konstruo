# typed: strict
# frozen_string_literal: true

require_relative 'address'

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
