warn("Loading devel/logger compatibility library...")
require 'logger'

module Devel
  class Logger < ::Logger
    module Severity
      SEV_DEBUG = 0
      SEV_INFO = 1
      SEV_WARN = 2
      SEV_ERROR = 3
      SEV_CAUTION = 4
      SEV_FATAL = 5
      SEV_UNKNOWN = 6
    end
    include Severity

    def debug?; @level >= DEBUG; end
    def info?; @level >= INFO; end
    def warn?; @level >= WARN; end
    def error?; @level >= ERROR; end
    def caution?; @level >= CAUTION; end
    def fatail?; @level >= FATAL; end
  end
  LogDevice = ::Logger::LogDevice
  class Application < ::Logger::Application
    include Devel::Logger::Severity
  end
end
