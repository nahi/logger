# Devel::Logger -- Logging utility.
#
# $Id: logger.rb,v 1.14 2003/06/01 10:08:24 nahi Exp $
#
# This module is copyrighted free software by NAKAMURA, Hiroshi.
# You can redistribute it and/or modify it under the same term as Ruby.
#
# See Devel::Logger at first.


module Devel


# DESCRIPTION
#   Devel::Logger -- Logging utility.
#
# How to create a logger.
#   1. Create logger which logs messages to STDERR/STDOUT.
#     logger = Devel::Logger.new(STDERR)
#     logger = Devel::Logger.new(STDOUT)
#
#   2. Create logger for the file which has the specified name.
#     logger = Devel::Logger.new('logfile.log')
#
#   3. Create logger for the specified file.
#     file = open('foo.log', File::WRONLY | File::APPEND)
#     # To create new (and to remove old) logfile, add File::CREAT like;
#     #   file = open('foo.log', File::WRONLY | File::APPEND | File::CREAT)
#     logger = Device::Logger.new(file)
#
#   4. Create logger which ages logfile automatically.  Leave 10 ages and each
#      file is about 102400 bytes.
#     logger = Device::Logger.new('foo.log', 10, 102400)
#
#   5. Create logger which ages logfile daily/weekly/monthly automatically.
#     logger = Logger.new('foo.log', 'daily')
#     logger = Logger.new('foo.log', 'weekly')
#     logger = Logger.new('foo.log', 'monthly')
#
# How to log a message.
#
#   1. Message in block.
#     logger.fatal { "Argument 'foo' not given." }
#
#   2. Message as a string.
#     logger.error "Argument #{ @foo } mismatch."
#
#   3. With progName.
#     logger.info('initialize') { "Initializing..." }
#
#   4. With severity.
#     logger.add(Devel::Logger::SEV_FATAL) { 'Fatal error!' }
#
# How to close a logger.
#
#   logger.close
#
# Setting severity threshold.
#
#   1. Original interface.
#     logger.sevThreshold = Devel::Logger::SEV_WARN
#
#   2. Log4r (somewhat) compatible interface.
#     logger.level = Devel::Logger::INFO
#
#   DEBUG < INFO < WARN < ERROR < CAUTION < FATAL < UNKNOWN
#
# Format.
#
#   Log format:
#     SeverityID, [Date Time mSec #pid] SeverityLabel -- ProgName: message
#
#   Log sample:
#     I, [Wed Mar 03 02:34:24 JST 1999 895701 #19074]  INFO -- Main: info.
#
class Logger

  /: (\S+),v (\S+)/ =~ %q$Id: logger.rb,v 1.14 2003/06/01 10:08:24 nahi Exp $
  ProgName = "#{$1}/#{$2}"

  class Error < RuntimeError; end
  class ShiftingError < Error; end

  # Logging severity.
  #   SEV_DEBUG
  #   SEV_INFO
  #   SEV_WARN
  #   SEV_ERROR
  #   SEV_CAUTION
  #   SEV_FATAL
  #   SEV_UNKNOWN
  module Severity
    SEV_DEBUG = 0
    SEV_INFO = 1
    SEV_WARN = 2
    SEV_ERROR = 3
    SEV_CAUTION = 4
    SEV_FATAL = 5
    SEV_UNKNOWN = 6
  end
  include Logger::Severity

  # Logging severity threshold.
  attr_accessor :sevThreshold

  # Logging program name.
  attr_accessor :progName

  # Logging date-time format (string passed to strftime)
  attr_accessor :datetimeFormat

  # Interface for Log4r compatibility.
  DEBUG = SEV_DEBUG
  INFO = SEV_INFO
  WARN = SEV_WARN
  ERROR = SEV_ERROR
  FATAL = SEV_FATAL

  # Interface for Log4r compatibility.
  def level=(newLevel)
    @sevThreshold = newLevel
  end

  # Interface for Log4r compatibility.
  def level
    @sevThreshold
  end

  # Interface for Log4r compatibility.
  def debug?;  @logDev and SEV_DEBUG >= @sevThreshold; end
  # Interface for Log4r compatibility.
  def info?;   @logDev and SEV_INFO  >= @sevThreshold; end
  # Interface for Log4r compatibility.
  def warn?;   @logDev and SEV_WARN  >= @sevThreshold; end
  # Interface for Log4r compatibility.
  def error?;  @logDev and SEV_ERROR >= @sevThreshold; end
  # Interface for Log4r compatibility.
  def fatal?;  @logDev and SEV_FATAL >= @sevThreshold; end

public

  # SYNOPSIS
  #   Logger.new(name, shiftAge = 7, shiftSize = 1048576)
  #
  # ARGS
  #   log	String as filename of logging.
  #		or
  #		IO as logging device(i.e. STDERR).
  #   shiftAge	An Integer	Num of files you want to keep aged logs.
  #		'daily'		Daily shifting.
  #		'weekly'	Weekly shifting (Every monday.)
  #		'monthly'	Monthly shifting (Every 1th day.)
  #   shiftSize	Shift size threshold when shiftAge is an integer.
  #		Otherwise (like 'daily'), shiftSize will be ignored.
  #
  # DESCRIPTION
  #   Create an instance.
  #
  def initialize(logDev, shiftAge = 0, shiftSize = 1048576)
    @progName = nil
    @logDev = LogDevice.new(logDev,
      :shiftAge => shiftAge, :shiftSize => shiftSize)
    @sevThreshold = SEV_DEBUG
    @kCode = nil
    @datetimeFormat = nil
  end

  # SYNOPSIS
  #   Logger#add(severity, msg = nil, progName = nil) { ... } = nil
  #
  # ARGS
  #   severity	Severity.  Constants are defined in Devel::Logger namespace.
  #		SEV_DEBUG, SEV_INFO, SEV_WARN, SEV_ERROR, SEV_CAUTION,
  #		SEV_FATAL, or SEV_UNKNOWN.
  #   msg	Message.  A string, exception, or something. Can be omitted.
  #   progName	Program name string.  Can be omitted.
  #   		Logged as a msg if no msg and block are given.
  #   block     Can be omitted.
  #             Called to get a message string if msg is nil.
  #
  # RETURN
  #   true if succeed, false if failed.
  #   When the given severity is not enough severe,
  #   Log no message, and returns true.
  #
  # DESCRIPTION
  #   Log a log if the given severity is enough severe.
  #
  # BUGS
  #   Logfile is not locked.
  #   Append open does not need to lock file.
  #   But on the OS which supports multi I/O, records possibly be mixed.
  #
  def add(severity, msg = nil, progName = nil, &block)
    severity ||= SEV_UNKNOWN
    if @logDev.nil? or severity < @sevThreshold
      return true
    end
    progName ||= @progName

    if msg.nil?
      if block_given?
	msg = yield
      else
	msg = progName
	progName = @progName
      end
    end

    if msg.is_a?(::Exception)
      msg = "#{ msg.message } (#{ msg.class })\n" <<
	(msg.backtrace || []).join("\n")
    elsif !msg.is_a?(::String)
      msg = msg.inspect
    end

    severityLabel = formatSeverity(severity)
    timestamp = formatDatetime(Time.now)
    msg = formatComment(msg)
    message = formatMessage(severityLabel, timestamp, msg, progName)
    @logDev.write(message)
    true
  end
  alias log add

  # SYNOPSIS
  #   Logger#debug(progName = nil) { ... } = nil
  #   Logger#info(progName = nil) { ... } = nil
  #   Logger#warn(progName = nil) { ... } = nil
  #   Logger#error(progName = nil) { ... } = nil
  #   Logger#caution(progName = nil) { ... } = nil
  #   Logger#fatal(progName = nil) { ... } = nil
  #   Logger#unknown(progName = nil) { ... } = nil
  #
  # ARGS
  #   progName	Program name string.  Can be omitted.
  #   		Logged as a msg if no block are given.
  #   block     Can be omitted.
  #             Called to get a message string if msg is nil.
  #
  # RETURN
  #   See Devel::Logger#add .
  #
  # DESCRIPTION
  #   Log a log.
  #
  def debug(progName = nil, &block)
    add(SEV_DEBUG, nil, progName, &block)
  end

  def info(progName = nil, &block)
    add(SEV_INFO, nil, progName, &block)
  end

  def warn(progName = nil, &block)
    add(SEV_WARN, nil, progName, &block)
  end

  def error(progName = nil, &block)
    add(SEV_ERROR, nil, progName, &block)
  end

  def caution(progName = nil, &block)
    add(SEV_CAUTION, nil, progName, &block)
  end

  def fatal(progName = nil, &block)
    add(SEV_FATAL, nil, progName, &block)
  end

  def unknown(progName = nil, &block)
    add(SEV_UNKNOWN, nil, progName, &block)
  end

  # SYNOPSIS
  #   Logger#close
  #
  # DESCRIPTION
  #   Close the logging device.
  #
  def close
    @logDev.close
  end

  # SYNOPSIS
  #   Logger#kCode=
  #
  # ARGS
  #   newKCode		Kconv::EUC, Kconv::JIS, or Kcode::SJIS.
  #
  # DESCRIPTION
  #   Set Japanese Kanji characters' encoding scheme of logfile.
  #   Once kCode is set, Logger tries to convert message's encoding scheme
  #   when logging new message.
  #
  def kCode=(newKCode)
    require 'kconv'
    @kCode = newKCode
  end

  def kCode
    @kCode
  end

private

  # Severity label for logging. (max 5 char)
  SEV_LABEL = %w(DEBUG INFO WARN ERROR CAUTN FATAL ANY);

  def formatSeverity(severity)
    SEV_LABEL[severity] || 'UNKNOWN'
  end

  def formatDatetime(dateTime)
    if @datetimeFormat.nil?
      dateTime.strftime("%Y-%m-%dT%H:%M:%S.") << "%6d" % dateTime.usec
    else
      dateTime.strftime(@datetimeFormat)
    end
  end

  def formatComment(msg)
    # Japanese Kanji char code conversion.
    if @kCode && (Kconv::guess(msg) != @kCode)
      msg = Kconv::kconv(msg, @kCode, Kconv::AUTO)
    end
    msg
  end

  def formatMessage(severity, timestamp, msg, progName)
    line = '%s, [%s #%d] %5s -- %s: %s' << "\n"
    line % [severity[0..0], timestamp, $$, severity, progName || '-', msg]
  end
end


# Devel::LogDevice -- Logging device.


class LogDevice
  attr_reader :dev
  attr_reader :fileName

  # SYNOPSIS
  #   Logger::LogDev.new(name, opt = {})
  #
  # ARGS
  #   log	String as filename of logging.
  #		  or
  #		IO as logging device(i.e. STDERR).
  #	opt	Hash of options.
  #
  # DESCRIPTION
  #   Log device class. Output and shifting of log.
  #
  # OPTIONS
  #   :shiftAge
  #     An Integer	Num of files you want to keep aged logs.
  #	  'daily'	Daily shifting.
  #	  'weekly'	Weekly shifting (Shift every monday.)
  #	  'monthly'	Monthly shifting (Shift every 1th day.)
  #
  #   :shiftSize	Shift size threshold when :shiftAge is an integer.
  #			Otherwise (like 'daily'), it is ignored.
  #
  def initialize(log = nil, opt = {})
    @dev = @fileName = @shiftAge = @shiftSize = nil
    if (log.is_a?(IO))
      # IO was given. Use it as a log device.
      @dev = log
    elsif (log.is_a?(String))
      # String was given. Open the file as a log device.
      @dev = openLogFile(log)
      @fileName = log
      @shiftAge = opt[:shiftAge] || 7
      @shiftSize = opt[:shiftSize] || 1048576
    else
      raise ArgumentError.new("Wrong argument: #{ log } for log.")
    end
  end

  # SYNOPSIS
  #   Logger::LogDev#write(message)
  #
  # ARGS
  #   message		Message to be logged.
  #
  # DESCRIPTION
  #   Log a message.  If needed, the log device is aged and the new device
  #  	is prepared.  Log device is not locked.  Append open does not need to
  #  	lock file but on the OS which supports multi I/O, records possibly be
  #  	mixed.
  #
  def write(message)
    if shiftLog?
      begin
	shiftLog
      rescue
	raise Logger::ShiftingError.new("Shifting failed. #{$!}")
      end
    end

    @dev.write(message) 
  end

  # SYNOPSIS
  #   Logger::LogDev#close
  #
  # DESCRIPTION
  #   Close the logging device.
  #
  def close
    @dev.close
  end

private

  def openLogFile(fileName)
    if (FileTest.exist?(fileName))
      open(fileName, (File::WRONLY | File::APPEND))
    else
      createLogFile(fileName)
    end
  end

  def createLogFile(fileName)
    logDev = open(fileName, (File::WRONLY | File::APPEND | File::CREAT))
    addLogHeader(logDev)
    logDev
  end

  def addLogHeader(file)
    file.write(
      "# Logfile created on %s by %s\n" % [Time.now.to_s, Logger::ProgName]
   )
  end

  SiD = 24 * 60 * 60

  def shiftLog?
    if !@shiftAge or !@dev.respond_to?(:stat)
      return false
    end
    if (@shiftAge.is_a?(Integer))
      # Note: always returns false if '0'.
      return (@fileName && (@shiftAge > 0) &&
	(@dev.stat.size > @shiftSize))
    else
      now = Time.now
      limitTime = case @shiftAge
	when /^daily$/
	  eod(now - 1 * SiD)
	when /^weekly$/
	  eod(now - ((now.wday + 1) * SiD))
	when /^monthly$/
	  eod(now - now.mday * SiD)
	else
	  now
	end
      return (@dev.stat.mtime <= limitTime)
    end
  end

  def shiftLog
    # At first, close the device if opened.
    if (@dev)
      @dev.close
      @dev = nil
    end
    if (@shiftAge.is_a?(Integer))
      (@shiftAge-3).downto(0) do |i|
	if (FileTest.exist?("#{@fileName}.#{i}"))
	  File.rename("#{@fileName}.#{i}", "#{@fileName}.#{i+1}")
  	end
      end
      File.rename("#{@fileName}", "#{@fileName}.0")
    else
      now = Time.now
      postfixTime = case @shiftAge
	when /^daily$/
	  eod(now - 1 * SiD)
	when /^weekly$/
	  eod(now - ((now.wday + 1) * SiD))
	when /^monthly$/
	  eod(now - now.mday * SiD)
	else
	  now
	end
      postfix = postfixTime.strftime("%Y%m%d")	# YYYYMMDD
      ageFile = "#{@fileName}.#{postfix}"
      if (FileTest.exist?(ageFile))
	raise RuntimeError.new("'#{ ageFile }' already exists.")
      end
      File.rename("#{@fileName}", ageFile)
    end

    @dev = createLogFile(@fileName)
    return true
  end

  def eod(t)
    Time.mktime(t.year, t.month, t.mday, 23, 59, 59)
  end
end


# DESCRIPTION
#   Devel::Application -- Add logging support to your application.
#
# USAGE
#   1. Define your application class as a sub-class of this class.
#   2. Override 'run' method in your class to do many things.
#   3. Instanciate it and invoke 'start'.
#
# EXAMPLE
#   class FooApp < Application
#     def initialize(fooApp, applicationSpecific, arguments)
#       super('FooApp') # Name of the application.
#     end
#
#     def run
#       ...
#       log(SEV_WARN, 'warning', 'myMethod1')
#       ...
#       @log.error('myMethod2') { 'Error!' }
#       ...
#     end
#   end
#
#   statusCode = FooApp.new(....).start
#
class Application
  include Devel::Logger::Severity

  attr_reader :appName, :logDev

  # SYNOPSIS
  #   Application.new(appName = '')
  #
  # ARGS
  #   appName	Name String of the application.
  #
  # DESCRIPTION
  #   Create an instance.  Log device is STDERR by default.
  #
  def initialize(appName = nil)
    @appName = appName
    @log = Devel::Logger.new(STDERR)
    @log.progName = @appName
    @sevThreshold = @log.sevThreshold
  end

  # SYNOPSIS
  #   Application#start
  #
  # DESCRIPTION
  #   Start the application.
  #
  # RETURN
  #   Status code.
  #
  def start
    status = -1
    begin
      log(SEV_INFO, "Start of #{ @appName }.")
      status = run
    rescue
      log(SEV_FATAL, "Detected an exception. Stopping ... #{$!} (#{$!.class})\n" << $@.join("\n"))
    ensure
      log(SEV_INFO, "End of #{ @appName }. (status: #{ status.to_s })")
    end
    status
  end

  # SYNOPSIS
  #   Application#setLog(log, shiftAge, shiftSize)
  #
  # ARGS
  #   (Args are explained in the class Devel::Logger)
  #
  # DESCRIPTION
  #   Set the log device for this application.
  #
  def setLog(logDev, shiftAge = 0, shiftSize = 102400)
    @log = Devel::Logger.new(logDev, shiftAge, shiftSize)
    @log.progName = @appName
    @log.sevThreshold = @sevThreshold
  end

  # SYNOPSIS
  #   Application#setSevThreshold(severity)
  #
  # ARGS
  #   sevThreshold	Severity threshold.
  #
  # DESCRIPTION
  #   Set severity threshold.
  #
  def setSevThreshold(sevThreshold)
    @sevThreshold = sevThreshold
    @log.sevThreshold = @sevThreshold
  end

protected

  # SYNOPSIS
  #   Application#log(severity, comment = nil) { ... }
  #
  # ARGS
  #   severity	Severity. See above to give this.
  #   comment	Message String.
  #   block     Can be omitted.
  #             Called to get a message String if comment is nil or omitted.
  #
  # DESCRIPTION
  #   Log a log if the given severity is enough severe.
  #   For more detail, see Log.add.
  #
  # RETURN
  #   true if succeed, false if failed.
  #   When the given severity is not enough severe,
  #   Log no message, and returns true.
  #
  def log(severity, message = nil, &block)
    @log.add(severity, message, @appName, &block) if @log
  end

private

  # private method 'run' must be defined in derived classes.
  def run # virtual
    raise RuntimeError.new('Method run must be defined in the derived class.')
  end
end


end
