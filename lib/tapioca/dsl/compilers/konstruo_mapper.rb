# typed: strict
# frozen_string_literal: true

require 'konstruo/mapper'
require 'tapioca/dsl/compiler'

module Tapioca
  module Dsl
    module Compilers
      class KonstruoMapper < Compiler
        extend T::Sig

        ConstantType = type_member { { fixed: T.class_of(::Konstruo::Mapper) } }

        sig { override.returns(T::Enumerable[T::Module[T.anything]]) }
        def self.gather_constants
          load_project_mapper_files!

          registry_descendants = if ::Konstruo::Mapper.respond_to?(:descendants)
            ::Konstruo::Mapper.descendants
          else
            []
          end

          objectspace_descendants = ObjectSpace.each_object(Class).select do |klass|
            klass < ::Konstruo::Mapper
          end

          (registry_descendants + objectspace_descendants).uniq.select { |klass| !klass.name.nil? }
        end

        sig { override.void }
        def decorate
          root.create_path(constant) do |klass|
            constant.fields.each do |field|
              field_type = as_type_string(field.type)
              accessor_type = field.required ? field_type : "T.nilable(#{field_type})"
              field_name = field.name.to_s

              klass.create_method(field_name, return_type: accessor_type)
              klass.create_method(
                "#{field_name}=",
                parameters:  [create_param('value', type: accessor_type)],
                return_type: accessor_type
              )
            end
          end
        end

        private

        sig { params(field_type: T.untyped).returns(String) }
        def as_type_string(field_type)
          if field_type == ::Konstruo::Boolean
            'T::Boolean'
          elsif field_type.is_a?(Array)
            element_type = field_type.first
            return 'T::Array[T.untyped]' unless element_type.is_a?(Class)

            "T::Array[#{class_name_or_untyped(element_type)}]"
          elsif field_type.is_a?(Class)
            class_name_or_untyped(field_type)
          else
            'T.untyped'
          end
        end

        sig { params(klass: T::Class[T.anything]).returns(String) }
        def class_name_or_untyped(klass)
          klass.name || 'T.untyped'
        end

        class << self
          extend T::Sig

          sig { void }
          def load_project_mapper_files!
            project_root = Pathname.new(Dir.pwd)
            roots = [
              project_root.join('app'),
              project_root.join('lib'),
              project_root.join('test'),
              project_root.join('spec')
            ]
            mapper_inheritance_regex = /<\s*::?\s*Konstruo\s*::\s*Mapper/
            candidate_files = T.let([], T::Array[String])
            matched_files = T.let([], T::Array[String])

            roots.each do |root|
              next unless root.exist?

              Dir[root.join('**/*.rb').to_s].sort.each do |path|
                next unless File.file?(path)

                candidate_files << path
                next unless File.read(path).match?(mapper_inheritance_regex)

                matched_files << path
                require path
              rescue LoadError, StandardError => e
                warn "[KonstruoMapper] skipped #{path}: #{e.class}: #{e.message}"
              end
            end

            return if mapper_descendants_loaded?

            files_to_try = matched_files.empty? ? candidate_files : (candidate_files - matched_files)
            files_to_try.each do |path|
              require path
            rescue LoadError, StandardError => e
              warn "[KonstruoMapper] skipped #{path}: #{e.class}: #{e.message}"
            end
          end

          sig { returns(T::Boolean) }
          def mapper_descendants_loaded?
            ObjectSpace.each_object(Class).any? { |klass| klass < ::Konstruo::Mapper }
          end
        end
      end
    end
  end
end
