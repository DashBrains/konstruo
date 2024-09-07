# typed: false
# frozen_string_literal: true

namespace :sorbet do
  namespace :update do
    desc 'Update Sorbet and RBIs.'
    task :all do
      Bundler.with_unbundled_env do
        # Generate requires
        system('bundle exec tapioca require')
        # Fetch remotes sources
        system('bundle exec tapioca annotations')
        # Generate gems' RBIs
        system('bundle exec tapioca gems')
        # Generate DSL' RBIs
        system('bundle exec tapioca dsl')
        # Bump typed: false to true
        system('bundle exec spoom srb bump')
        # Bump typed: true to strict
        system('bundle exec spoom srb bump --from true --to strict')
        # Bump typed: strict to strong
        system('bundle exec spoom srb bump --from strict --to strong')
      end
    end
  end
end
