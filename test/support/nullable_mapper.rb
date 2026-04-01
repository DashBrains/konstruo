# typed: strict
# frozen_string_literal: true

require 'konstruo/mapper'

class NullableMapper < Konstruo::Mapper
  field :required_non_nullable_default, String, required: true
  field :optional_nullable_default, String, required: false
  field :required_nullable, String, required: true, nullable: true
  field :required_non_nullable, String, required: true, nullable: false
  field :optional_non_nullable, String, required: false, nullable: false
end
