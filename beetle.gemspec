Gem::Specification.new do |s|
  s.name    = "beetle"
  s.version = "0.2.10"
  s.required_rubygems_version = ">= 1.3.1"
  s.authors            = ["Stefan Kaes", "Pascal Friederich", "Ali Jelveh", "Sebastian Roebke"]
  s.date               = Time.now.strftime('%Y-%m-%d')
  s.default_executable = "beetle"
  s.description        = "A highly available, reliable messaging infrastructure"
  s.summary            = "High Availability AMQP Messaging with Redundant Queues"
  s.email              = "developers@xing.com"
  s.executables        = ["beetle"]
  s.extra_rdoc_files   = Dir['**/*.rdoc'] + %w(MIT-LICENSE)
  s.files              = Dir['{examples,lib}/**/*.rb'] + Dir['{features,script}/**/*'] + %w(beetle.gemspec Rakefile)
  s.homepage           = "http://xing.github.com/beetle/"
  s.rdoc_options       = ["--charset=UTF-8"]
  s.require_paths      = ["lib"]
  s.rubygems_version   = "1.3.7"
  s.test_files         = Dir['test/**/*.rb']

  s.post_install_message = <<-INFO
  *********************************************************************************************

    Please install the SystemTimer gem if you're running a ruby version < 1.9:
    `gem install SystemTimer -v '=1.2.1'`
    See: http://ph7spot.com/musings/system-timer

  *********************************************************************************************
  INFO

  s.specification_version = 3
  
  # TODO: need to figure out how to do this for both jruby & mri
  
  unless defined?(::JRUBY_VERSION)
    s.add_runtime_dependency("uuid4r",                [">= 0.1.1"])
  end

  s.add_runtime_dependency("bunny",                 ["= 0.6.0"])
  s.add_runtime_dependency("bunny-ext",             [">= 0.6.5"])
  s.add_runtime_dependency("redis",                 ["= 2.0.4"])
  s.add_runtime_dependency("amqp",                  [">= 0.6.7"])
  s.add_runtime_dependency('i18n',                  [">= 0.5.0"])
  s.add_runtime_dependency("activesupport",         ["~> 3.0.0"])
  s.add_runtime_dependency("daemons",               [">= 1.0.10"])
  s.add_development_dependency("mocha",             [">= 0"])
  s.add_development_dependency("rcov",              [">= 0"])
  s.add_development_dependency("cucumber",          [">= 0.7.2"])
  s.add_development_dependency("daemon_controller", [">= 0"])
end

