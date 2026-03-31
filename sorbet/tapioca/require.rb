# typed: strong
# frozen_string_literal: true

require 'action_controller'
require 'action_controller/metal/strong_parameters'
require 'active_support/all'
require 'minitest/autorun'
require 'rails/all'
require 'sorbet-runtime'

Dir[File.expand_path('../../test/support/*.rb', __dir__)].sort.each { |path| require path }

require 'konstruo/mapper'
