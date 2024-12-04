Gem::Specification.new do |s|
  s.name             = "cpee-eval-ruby"
  s.version          = "1.0.8"
  s.platform         = Gem::Platform::RUBY
  s.license          = "LGPL-3.0-or-later"
  s.summary          = "Ruby eval for the cloud process execution engine (cpee.org)"

  s.description      = "see http://cpee.org"

  s.files            = Dir['{server/**/*,tools/**/*,lib/**/*}'] + %w(LICENSE Rakefile cpee-eval-ruby.gemspec README.md AUTHORS)
  s.require_path     = 'lib'
  s.extra_rdoc_files = ['README.md']
  s.bindir           = 'tools'
  s.executables      = ['cpee-eval-ruby']

  s.required_ruby_version = '>=2.4.0'

  s.authors          = ['Juergen eTM Mangler']

  s.email            = 'juergen.mangler@gmail.com'
  s.homepage         = 'http://cpee.org/'

  s.add_runtime_dependency 'riddl', '~> 1.0'
  s.add_runtime_dependency 'weel', '~> 1.99'
end
