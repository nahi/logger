#!/usr/bin/env ruby

$:.push( File.join( '..', 'lib' ))
require 'devel/logger'

log = Devel::Logger.new( STDERR )

def doLog( log )
  log.debug( 'doLog1' ) { "debug" }
  log.info( 'doLog2' ) { "info" }
  log.warn( 'doLog3' ) { "warn" }
  log.error( 'doLog4' ) { "error" }
  log.caution( 'doLog5' ) { "caution" }
  log.fatal( 'doLog6' ) { "fatal" }
  log.unknown( 'doLog7' ) { "unknown" }
end

log.sevThreshold = Devel::Logger::SEV_DEBUG	# Default.
doLog( log )

puts "Set severity threshold 'WARN'."

log.sevThreshold = Devel::Logger::SEV_WARN
doLog( log )
