require 'rubygems'
SPEC = Gem::Specification.new do |s|
  require './lib/logger.rb'
  s.name = "logger"
  s.version = Logger::VERSION
  s.date = "2011-05-14"
  s.author = "NAKAMURA, Hiroshi"
  s.email = "nahi@ruby-lang.org"
  s.homepage = "http://github.com/nahi/logger"
  s.platform = Gem::Platform::RUBY
  s.summary = "simple logging utility"
  s.files = ["README", "lib/logger.rb", "test/test_logger.rb", *Dir.glob("sample/*.rb")]
  s.require_path = "lib"
end
