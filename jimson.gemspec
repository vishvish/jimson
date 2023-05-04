$LOAD_PATH.unshift("#{File.dirname(__FILE__)}/lib/")
require 'jimson/version'

Gem::Specification.new do |s|
  s.required_ruby_version = '>= 3.1'
  s.name = 'jimson'
  s.version = Jimson::VERSION
  s.authors = ['Chris Kite', 'Gilbert', 'Bodo Tasche']
  s.homepage = 'https://github.com/bitboxer/jimson.git'
  s.licenses = ['MIT']
  s.platform = Gem::Platform::RUBY
  s.summary = 'JSON-RPC 2.0 client and server'
  s.require_path = 'lib'
  s.extra_rdoc_files = ['README.md']
  s.add_dependency('blankslate',  '>= 3.1.3')
  s.add_dependency('multi_json', '>= 1.15.0')
  s.add_dependency('rack', '>= 2.2.0')
  s.add_dependency('rest-client', '>= 2.1.0')
  s.add_development_dependency('rack-test')
  s.add_development_dependency('rake')
  s.add_development_dependency('rdoc', '>= 4.2.2', '~> 6.3')
  s.add_development_dependency('rspec', '~> 3.12', '>= 3.12.0')
  s.add_development_dependency('pry')

  s.files = %w[
    LICENSE.txt
    CHANGELOG.md
    README.md
    Rakefile
  ] + Dir['lib/**/*.rb']

  s.test_files = Dir['spec/*.rb']
end
