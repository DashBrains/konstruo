# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'
require_relative 'konstruo/version'
require_relative 'konstruo/mapper'

module Konstruo
  class ValidationError < StandardError; end

  class Boolean
    extend T::Sig

    sig { params(value: T.untyped).returns(Boolean) }
    def self.boolean?(value)
      value.is_a?(TrueClass) || value.is_a?(FalseClass)
    end
  end
end
