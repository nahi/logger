STDERR.puts("Loading devel/logger compatibility library...")
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
    alias sevThreshold level
    alias sevThreshold= level=
  end
  LogDevice = ::Logger::LogDevice
  class Application < ::Logger::Application
    include Devel::Logger::Severity
    def initialize(*arg)
      super
      setLog(STDERR)
    end
    def setLog(logdev, shift_age = 0, shift_size = 102400)
      @log = Devel::Logger.new(logdev, shift_age, shift_size)
      @log.progname = @appname
      @log.level = @level
    end
  end
end
