# typed: strict
# frozen_string_literal: true

require 'minitest/autorun'
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'konstruo'

Dir[File.expand_path('support/*.rb', __dir__)].sort.each { |path| require path }
