# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'

Dir['tasks/**/*.rake'].each { |t| load t }

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
end

task default: :test
