module ARTest
  module CockroachDB

    extend self

    def root_cockroachdb
      File.expand_path File.join(File.dirname(__FILE__), '..', '..')
    end

    def test_root_cockroachdb
      File.join root_cockroachdb, 'test'
    end

    def root_activerecord
      File.join Gem.loaded_specs['rails'].full_gem_path, 'activerecord'
    end

    def root_activerecord_lib
      File.join root_activerecord, 'lib'
    end

    def root_activerecord_test
      File.join root_activerecord, 'test'
    end

    def test_load_paths
      ['lib', 'test', root_activerecord_lib, root_activerecord_test]
    end

    def add_to_load_paths!
      test_load_paths.each { |p| $LOAD_PATH.unshift(p) unless $LOAD_PATH.include?(p) }
    end

    def arconfig_file
      File.join test_root_cockroachdb, 'config.yml'
    end

    def arconfig_file_env!
      ENV['ARCONFIG'] = arconfig_file
    end

  end
end

ARTest::CockroachDB.add_to_load_paths!
ARTest::CockroachDB.arconfig_file_env!
