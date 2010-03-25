Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'artifice'
  s.version     = '0.5'
  s.summary     = 'Use a Rack application for mock HTTP requests'
  s.description = 'Replaces Net::HTTP with a subclass that routes all requests to a Rack application'
  s.required_ruby_version = '>= 1.8.6'

  s.author            = 'Yehuda Katz'
  s.email             = 'wycats@gmail.com'
  s.homepage          = 'http://www.yehudakatz.com'
  s.rubyforge_project = 'artifice'

  s.files              = Dir['README.markdown', 'LICENSE', 'lib/**/{*,.[a-z]*}']
  s.require_path       = 'lib'

  s.rdoc_options << '--exclude' << '.'
  s.has_rdoc = false

  s.add_dependency "rack-test"
end
