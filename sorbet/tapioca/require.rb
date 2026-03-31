# typed: strong
# frozen_string_literal: true

require 'action_controller'
require 'action_controller/metal/strong_parameters'
require 'active_support/all'
require 'minitest/autorun'
require 'rails/all'
require 'sorbet-runtime'

sample_mappers = File.expand_path('../../test/support/sample_mappers.rb', __dir__)
require sample_mappers if File.exist?(sample_mappers)

require 'konstruo/mapper'
