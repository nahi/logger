# Devel::Logger -- Logging utility.
#
# $Id: logger.rb,v 1.16 2003/09/16 13:02:41 nahi Exp $
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
#   3. With prog_name.
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
#     logger.sev_threshold = Devel::Logger::SEV_WARN
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

  /: (\S+),v (\S+)/ =~ %q$Id: logger.rb,v 1.16 2003/09/16 13:02:41 nahi Exp $
  ProgName = "#{$1}/#{$2}"

  class Error < RuntimeError; end
  class ShiftingError < Error; end

  # Logging severity.
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
  attr_accessor :sev_threshold

  # Logging program name.
  attr_accessor :prog_name

  # Logging date-time format (string passed to strftime)
  attr_accessor :datetime_format

  # Interface for backward compatibility.
  alias sevThreshold sev_threshold
  alias sevThreshold= sev_threshold=
  alias progName prog_name
  alias progName= prog_name=
  alias datetimeFormat datetime_format
  alias datetimeFormat= datetime_format=

  # Interface for Log4r compatibility.
  DEBUG = SEV_DEBUG
  INFO = SEV_INFO
  WARN = SEV_WARN
  ERROR = SEV_ERROR
  FATAL = SEV_FATAL

  # Interface for Log4r compatibility.
  alias level sev_threshold
  alias level= sev_threshold=

  # Interface for Log4r compatibility.
  def debug?; @logdev and SEV_DEBUG >= @sev_threshold; end
  # Interface for Log4r compatibility.
  def info?;  @logdev and SEV_INFO  >= @sev_threshold; end
  # Interface for Log4r compatibility.
  def warn?;  @logdev and SEV_WARN  >= @sev_threshold; end
  # Interface for Log4r compatibility.
  def error?; @logdev and SEV_ERROR >= @sev_threshold; end
  # Interface for Log4r compatibility.
  def fatal?; @logdev and SEV_FATAL >= @sev_threshold; end

public

  # SYNOPSIS
  #   Logger.new(name, shift_age = 7, shift_size = 1048576)
  #
  # ARGS
  #   log	String as filename of logging.
  #		or
  #		IO as logging device(i.e. STDERR).
  #   shift_age	An Integer	Num of files you want to keep aged logs.
  #		'daily'		Daily shifting.
  #		'weekly'	Weekly shifting (Every monday.)
  #		'monthly'	Monthly shifting (Every 1th day.)
  #   shift_size	Shift size threshold when shift_age is an integer.
  #		Otherwise (like 'daily'), shift_size will be ignored.
  #
  # DESCRIPTION
  #   Create an instance.
  #
  def initialize(logdev, shift_age = 0, shift_size = 1048576)
    @prog_name = nil
    @logdev = LogDevice.new(logdev, :shift_age => shift_age, :shift_size => shift_size)
    @sev_threshold = SEV_DEBUG
    @datetime_format = nil
  end

  # SYNOPSIS
  #   Logger#add(severity, msg = nil, prog_name = nil) { ... } = nil
  #
  # ARGS
  #   severity	Severity.  Constants are defined in Devel::Logger namespace.
  #		SEV_DEBUG, SEV_INFO, SEV_WARN, SEV_ERROR, SEV_CAUTION,
  #		SEV_FATAL, or SEV_UNKNOWN.
  #   msg	Message.  A string, exception, or something. Can be omitted.
  #   prog_name	Program name string.  Can be omitted.
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
  def add(severity, msg = nil, prog_name = nil, &block)
    severity ||= SEV_UNKNOWN
    if @logdev.nil? or severity < @sev_threshold
      return true
    end
    prog_name ||= @prog_name

    if msg.nil?
      if block_given?
	msg = yield
      else
	msg = prog_name
	prog_name = @prog_name
      end
    end

    if msg.is_a?(::Exception)
      msg = "#{ msg.message } (#{ msg.class })\n" << (msg.backtrace || []).join("\n")
    elsif !msg.is_a?(::String)
      msg = msg.inspect
    end

    severity_label = format_severity(severity)
    timestamp = format_datetime(Time.now)
    message = format_message(severity_label, timestamp, msg, prog_name)
    @logdev.write(message)
    true
  end
  alias log add

  # SYNOPSIS
  #   Logger#debug(prog_name = nil) { ... } = nil
  #   Logger#info(prog_name = nil) { ... } = nil
  #   Logger#warn(prog_name = nil) { ... } = nil
  #   Logger#error(prog_name = nil) { ... } = nil
  #   Logger#caution(prog_name = nil) { ... } = nil
  #   Logger#fatal(prog_name = nil) { ... } = nil
  #   Logger#unknown(prog_name = nil) { ... } = nil
  #
  # ARGS
  #   prog_name	Program name string.  Can be omitted.
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
  def debug(prog_name = nil, &block)
    add(SEV_DEBUG, nil, prog_name, &block)
  end

  def info(prog_name = nil, &block)
    add(SEV_INFO, nil, prog_name, &block)
  end

  def warn(prog_name = nil, &block)
    add(SEV_WARN, nil, prog_name, &block)
  end

  def error(prog_name = nil, &block)
    add(SEV_ERROR, nil, prog_name, &block)
  end

  def caution(prog_name = nil, &block)
    add(SEV_CAUTION, nil, prog_name, &block)
  end

  def fatal(prog_name = nil, &block)
    add(SEV_FATAL, nil, prog_name, &block)
  end

  def unknown(prog_name = nil, &block)
    add(SEV_UNKNOWN, nil, prog_name, &block)
  end

  # SYNOPSIS
  #   Logger#close
  #
  # DESCRIPTION
  #   Close the logging device.
  #
  def close
    @logdev.close
  end

private

  # Severity label for logging. (max 5 char)
  SEV_LABEL = %w(DEBUG INFO WARN ERROR CAUTN FATAL ANY);

  def format_severity(severity)
    SEV_LABEL[severity] || 'UNKNOWN'
  end

  def format_datetime(datetime)
    if @datetime_format.nil?
      datetime.strftime("%Y-%m-%dT%H:%M:%S.") << "%6d" % datetime.usec
    else
      datetime.strftime(@datetime_format)
    end
  end

  def format_message(severity, timestamp, msg, prog_name)
    line = '%s, [%s #%d] %5s -- %s: %s' << "\n"
    line % [severity[0..0], timestamp, $$, severity, prog_name || '-', msg]
  end
end


# Devel::LogDevice -- Logging device.


class LogDevice
  attr_reader :dev
  attr_reader :filename
  alias fileName filename

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
  #   :shift_age
  #     An Integer	Num of files you want to keep aged logs.
  #	  'daily'	Daily shifting.
  #	  'weekly'	Weekly shifting (Shift every monday.)
  #	  'monthly'	Monthly shifting (Shift every 1th day.)
  #
  #   :shift_size	Shift size threshold when :shift_age is an integer.
  #			Otherwise (like 'daily'), it is ignored.
  #
  def initialize(log = nil, opt = {})
    @dev = @filename = @shift_age = @shift_size = nil
    if (log.is_a?(IO))
      # IO was given. Use it as a log device.
      @dev = log
    elsif (log.is_a?(String))
      # String was given. Open the file as a log device.
      @dev = open_logfile(log)
      @filename = log
      @shift_age = opt[:shift_age] || 7
      @shift_size = opt[:shift_size] || 1048576
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
    if shift_log?
      begin
	shift_log
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

  def open_logfile(filename)
    if (FileTest.exist?(filename))
      open(filename, (File::WRONLY | File::APPEND))
    else
      create_logfile(filename)
    end
  end

  def create_logfile(filename)
    logdev = open(filename, (File::WRONLY | File::APPEND | File::CREAT))
    add_log_header(logdev)
    logdev
  end

  def add_log_header(file)
    file.write(
      "# Logfile created on %s by %s\n" % [Time.now.to_s, Logger::ProgName]
   )
  end

  SiD = 24 * 60 * 60

  def shift_log?
    if !@shift_age or !@dev.respond_to?(:stat)
      return false
    end
    if (@shift_age.is_a?(Integer))
      # Note: always returns false if '0'.
      return (@filename && (@shift_age > 0) &&
	(@dev.stat.size > @shift_size))
    else
      now = Time.now
      limit_time = case @shift_age
	when /^daily$/
	  eod(now - 1 * SiD)
	when /^weekly$/
	  eod(now - ((now.wday + 1) * SiD))
	when /^monthly$/
	  eod(now - now.mday * SiD)
	else
	  now
	end
      return (@dev.stat.mtime <= limit_time)
    end
  end

  def shift_log
    # At first, close the device if opened.
    if (@dev)
      @dev.close
      @dev = nil
    end
    if (@shift_age.is_a?(Integer))
      (@shift_age-3).downto(0) do |i|
	if (FileTest.exist?("#{@filename}.#{i}"))
	  File.rename("#{@filename}.#{i}", "#{@filename}.#{i+1}")
  	end
      end
      File.rename("#{@filename}", "#{@filename}.0")
    else
      now = Time.now
      postfix_time = case @shift_age
	when /^daily$/
	  eod(now - 1 * SiD)
	when /^weekly$/
	  eod(now - ((now.wday + 1) * SiD))
	when /^monthly$/
	  eod(now - now.mday * SiD)
	else
	  now
	end
      postfix = postfix_time.strftime("%Y%m%d")	# YYYYMMDD
      age_file = "#{@filename}.#{postfix}"
      if (FileTest.exist?(age_file))
	raise RuntimeError.new("'#{ age_file }' already exists.")
      end
      File.rename("#{@filename}", age_file)
    end

    @dev = create_logfile(@filename)
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
#     def initialize(foo_app, application_specific, arguments)
#       super('FooApp') # Name of the application.
#     end
#
#     def run
#       ...
#       log(SEV_WARN, 'warning', 'my_method1')
#       ...
#       @log.error('my_method2') { 'Error!' }
#       ...
#     end
#   end
#
#   status = FooApp.new(....).start
#
class Application
  include Devel::Logger::Severity

  attr_reader :app_name
  attr_reader :logdev
  alias logDev logdev

  # SYNOPSIS
  #   Application.new(app_name = '')
  #
  # ARGS
  #   app_name	Name String of the application.
  #
  # DESCRIPTION
  #   Create an instance.  Log device is STDERR by default.
  #
  def initialize(app_name = nil)
    @app_name = app_name
    @log = Devel::Logger.new(STDERR)
    @log.prog_name = @app_name
    @sev_threshold = @log.sev_threshold
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
      log(SEV_INFO, "Start of #{ @app_name }.")
      status = run
    rescue
      log(SEV_FATAL, "Detected an exception. Stopping ... #{$!} (#{$!.class})\n" << $@.join("\n"))
    ensure
      log(SEV_INFO, "End of #{ @app_name }. (status: #{ status.to_s })")
    end
    status
  end

  # SYNOPSIS
  #   Application#log=(log, shift_age, shift_size)
  #
  # ARGS
  #   (Args are explained in the class Devel::Logger)
  #
  # DESCRIPTION
  #   Set the log device for this application.
  #
  def log=(logdev, shift_age = 0, shift_size = 102400)
    @log = Devel::Logger.new(logdev, shift_age, shift_size)
    @log.prog_name = @app_name
    @log.sev_threshold = @sev_threshold
  end
  alias setLog log=

  # SYNOPSIS
  #   Application#sev_threshold=(severity)
  #
  # ARGS
  #   sev_threshold	Severity threshold.
  #
  # DESCRIPTION
  #   Set severity threshold.
  #
  def sev_threshold=(sev_threshold)
    @sev_threshold = sev_threshold
    @log.sev_threshold = @sev_threshold
  end
  alias setSevThreshold sev_threshold=

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
    @log.add(severity, message, @app_name, &block) if @log
  end

private

  # private method 'run' must be defined in derived classes.
  def run # virtual
    raise RuntimeError.new('Method run must be defined in the derived class.')
  end
end


end
