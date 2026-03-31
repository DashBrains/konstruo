# typed: strict
# frozen_string_literal: true

require 'konstruo/mapper'

class LoosePersonMapper < Konstruo::Mapper
  field :name, String, required: true
end
