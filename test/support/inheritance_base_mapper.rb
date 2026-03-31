# typed: strict
# frozen_string_literal: true

require 'konstruo/mapper'

class InheritanceBaseMapper < Konstruo::Mapper
  field :id, Integer, required: true
end
