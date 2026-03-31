# typed: strict
# frozen_string_literal: true

require 'konstruo/mapper'

class StrictPersonMapper < Konstruo::Mapper
  strict_unknown_keys
  field :name, String, required: true
end
