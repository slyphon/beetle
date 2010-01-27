require 'rake'
require 'rake/testtask'

task :trace do
  trap('INT'){ EM.stop_event_loop }
  Bandersnatch::Base.configuration do |config|
    config.logger.formatter = XINGLogging::SyslogCompliantLogFormatter.new
  end

  Bandersnatch::Base.new(:sub).trace
end

task :default do
  Rake::Task[:test].invoke
end

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name    = 'banderstnatch'
    gemspec.version = '0.0.1'
    gemspec.summary = "Messages :P"
    gemspec.description = "A high available/reliabile messaging infrastructure"
    gemspec.email = "developers@xing.com"
    gemspec.authors = ["Stefan Kaes", "Pascal Friederich"]
    gemspec.add_dependency('uuid4r', '0.1.1')
    gemspec.add_dependency('bunny')
    gemspec.add_dependency('redis', '1.2.1')
    gemspec.add_dependency('amqp')
    gemspec.add_development_dependency('mocha')
    gemspec.add_development_dependency('active_support', '2.3.5')
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

