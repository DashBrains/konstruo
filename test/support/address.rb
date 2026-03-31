# typed: strict
# frozen_string_literal: true

require 'konstruo/mapper'

class Address < Konstruo::Mapper
  field :street, String, required: true, error_message: 'Street is required.'
  field :city, String, required: true
end
