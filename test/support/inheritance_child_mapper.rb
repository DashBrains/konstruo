# typed: strict
# frozen_string_literal: true

require_relative 'inheritance_base_mapper'

class InheritanceChildMapper < InheritanceBaseMapper
  field :name, String, required: true
end
