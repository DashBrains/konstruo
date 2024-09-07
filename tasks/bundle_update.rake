# typed: false
# frozen_string_literal: true

namespace :bundle do
  desc 'Update all gems'
  task :update do
    Bundler.with_unbundled_env do
      # Update bundler version
      system('bundle update --bundler')
      # Update bundle gems
      system('bundle update')
    end
  end
end
