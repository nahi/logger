# Log -- Log dumping utility class.
# Application -- Easy logging application class.

# $Id: application.rb,v 1.2 1999/07/03 10:26:44 nakahiro Exp $


# SYNOPSIS
#   Log.new( log, shiftAge, shiftSize )
#
# ARGS
#   log		String as filename of logging.
#		  or
#		IO as logging device(i.e. STDERR).
#   shiftAge	Num of files you want to keep aged logs.
#   shiftSize	Shift size threshold.
#
# DESCRIPTION
#   Log dumping utility class.
#
#   Log format:
#     SeverityID, [ Date Time MicroSec #pid] SeverityLabel -- ProgName: message
#
#   Log sample:
#     I, [Wed Mar 03 02:34:24 JST 1999 895701 #19074]  INFO -- Main: Only info.
#
#   Sample usage1:
#     file = open( 'foo.log', 'a' )
#     logDev = Log.new( file )
#     logDev.add( Log::SEV_WARN, 'It is only warning!', 'MyProgram' )
#   	...
#     logDev.close()
#
#   Sample usage2:
#     logDev = Log.new( 'logfile.log', 10, 102400 )
#     logDev.add( Log::SEV_CAUTION, 'It is caution!', 'MyProgram' )
#   	...
#     logDev.close()
#
#   Sample usage3:
#     logDev = Log.new( STDERR )
#     logDev.add( Log::SEV_FATAL, 'It is fatal error...' )
#     	...
#     logDev.close()
#
require 'kconv'
class Log # throw Log::Error
  public
  class Error < RuntimeError; end
  class ShiftingError < Error; end

  # Logging severity.
  public
  module Severity
    SEV_DEBUG = 0
    SEV_INFO = 1
    SEV_WARN = 2
    SEV_ERROR = 3
    SEV_CAUTION = 4
    SEV_FATAL = 5
  end
  include Log::Severity

  # Japanese Kanji characters' encoding scheme of logfile.
  #   Kconv::EUC, Kconv::JIS, or Kcode::SJIS.
  attr( :kCode, TRUE )

  # Logging severity threshold.
  attr( :sevThreshold, TRUE )

  # SYNOPSIS
  #   Log.add( severity, comment, program )
  #
  # ARGS
  #   severity	Severity. See above to give this.
  #   comment	Message String.
  #   program	Program name String.
  #
  # DESCRIPTION
  #   Log a log if the given severity is enough severe.
  #
  # BUGS
  #   Logfile is not locked.
  #   Append open does not need to lock file.
  #   But on the OS which supports multi I/O, records possibly be mixed.
  #
  # RETURN
  #   true if succeed, false if failed.
  #   When the given severity is not enough severe,
  #   Log no message, and returns true.
  #
  public
  def add( severity, comment, program = '_unknown_' )
    return true if ( severity < @sevThreshold )
    if ( @logDev.shiftLog? ) then
      begin
      	@logDev.shiftLog
      rescue
	raise Log::ShiftingError.new( "Shifting failed. #{$!}" )
      end
      @logDev.dev = createLogFile( @logDev.fileName )
    end
    severityLabel = Log.formatSeverity( severity )
    timestamp = Log.formatDatetime( Time.now )
    comment = Log.formatComment( comment )
    message = Log.formatMessage( severityLabel, timestamp, comment, program )
    @logDev.write( message )
    true
  end

  # SYNOPSIS
  #   Log.close()
  #
  # DESCRIPTION
  #   Close the logging device.
  #
  # RETURN
  #   Always nil.
  #
  public
  def close()
    @logDev.close()
    nil
  end

  private

  # Log::LogDev -- log device class. Output and shifting of log.
  class LogDev
    attr( :dev, TRUE )
    attr( :fileName, TRUE )
    attr( :shiftAge, TRUE )
    attr( :shiftSize, TRUE )

    public
    def write( message )
      # Maybe OS seeked to the last automatically,
      #  when the file was opened with append mode...
      @dev.syswrite( message ) 
    end

    public
    def close()
      @dev.close()
    end

    public
    def shiftLog?
      ( @fileName && ( @shiftAge > 0 ) && ( @dev.stat[7] > @shiftSize ))
    end

    public
    def shiftLog
      # At first, close the device if opened.
      if ( @dev ) then
	@dev.close
	@dev = nil
      end
      ( @shiftAge-3 ).downto( 0 ) do |i|
      	if ( FileTest.exist?( "#{@fileName}.#{i}" )) then
	  File.rename( "#{@fileName}.#{i}", "#{@fileName}.#{i+1}" )
      	end
      end
      File.rename( "#{@fileName}", "#{@fileName}.0" )
      true
    end

    private
    def initialize( dev = nil, fileName = nil )
      @dev = dev
      @fileName = fileName
      @shiftAge = nil
      @shiftSize = nil
    end
  end

  def initialize( log, shiftAge = 3, shiftSize = 102400 )
    @logDev = nil
    if ( log.is_a?( IO )) then
      # IO was given. Use it as a log device.
      @logDev = LogDev.new( log )
    elsif ( log.is_a?( String )) then
      # String was given. Open the file as a log device.
      dev = if ( FileTest.exist?( log.to_s )) then
          open( log.to_s, "a" )
      	else
	  createLogFile( log.to_s )
      	end
      @logDev = LogDev.new( dev, log )
    else
      raise ArgumentError.new( 'Wrong argument(log)' )
    end
    @logDev.shiftAge = shiftAge
    @logDev.shiftSize = shiftSize
    @sevThreshold = SEV_DEBUG
    @kCode = Kconv::EUC
  end

  def createLogFile( fileName )
    logDev = open( fileName, 'a' )
    addLogHeader( logDev )
    logDev
  end

  def addLogHeader( file )
    file.syswrite( "# Logfile created on %s by %s\n" %
      [ Time.now.to_s, ProgName ])
  end

  %q$Id: application.rb,v 1.2 1999/07/03 10:26:44 nakahiro Exp $ =~ /: (\S+),v (\S+)/
  ProgName = "#{$1}/#{$2}"

  # Severity label for logging. ( max 5 char )
  SEV_LABEL = %w( DEBUG INFO WARN ERROR CAUTN FATAL ANY );

  def Log.formatSeverity( severity )
    SEV_LABEL[ severity ] || 'UNKNOWN'
  end

  def Log.formatDatetime( dateTime )
    dateTime.to_s << ' ' << "%6d" % dateTime.usec
  end

  def Log.formatComment( comment )
    newComment = comment.dup
    # Remove white characters at the end of line.
    newComment.sub!( '/[ \t\r\f\n]*$/', '' )
    # Japanese Kanji char code conversion.
    newComment = Kconv::kconv( newComment, @kCode, Kconv::AUTO )
    newComment
  end

  def Log.formatMessage( severity, timestamp, comment, program )
    message = '%s, [%s #%d] %5s -- %s: %s' << "\n"
    message % [ severity[ 0 .. 0 ], timestamp, $$, severity, program, comment ]
  end
end


# SYNOPSIS
#   Application.new( appName )
#
# ARGS
#   appName	Name String of the application.
#
# DESCRIPTION
#   An application for easy logging.
#
class Application
  include Log::Severity

  attr_reader :appName, :logDev, :status

  # SYNOPSIS
  #   Application.start()
  #
  # DESCRIPTION
  #   Start the application.
  #
  # RETURN
  #   Status code.
  #
  public
  def start()
    @log = Log.new( @logDev, @shiftAge, @shiftSize )
    begin
      log( SEV_INFO, "Start of #{ @appName }." )
      @status = run()
    rescue
      log( SEV_FATAL, "Detected an exception. Stopping ... #{$!}\n" <<
	$@.join( "\n" ))
    ensure
      log( SEV_INFO, "End of #{ @appName }. (status: #{ @status.to_s })" )
    end
    @status
  end

  # SYNOPSIS
  #   Application.setLog( log, shiftAge, shiftSize )
  #
  # ARGS
  #   ( see class Log )
  #
  # DESCRIPTION
  #   Log device setting of the application.
  #
  # RETURN
  #   Always true.
  #
  public
  def setLog( log, shiftAge = 0, shiftSize = 102400 )
    @logDev = log
    @shiftAge = shiftAge
    @shiftSize = shiftSize
    true
  end

  protected
  def log( severity, message )
    @log.add( severity, message, @appName )
  end

  private
  def initialize( name = '' )
    @appName = name
    @status = false
    @logDev = STDERR
    @shiftAge = 0	# means 'no shifting'
    @shiftSize = 102400
  end

  # private method 'run' must be defined in derived classes.
  private # virtual
  def run()
    raise RuntimeError.new( 'Method run must be defined in the derived class.' )
  end
end

=begin
    Log -- Log dumping utility class.
    Application -- Easy logging application class.
    Copyright (C) 1999  NAKAMURA, Hiroshi

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
=end
