#!/usr/bin/env ruby

$:.unshift( File.join( '..', 'lib' ))
require 'devel/logger'

logFile = File.join( 'logs', 'logShifting.log' )
# Max 3 age ... logShifting.log, logShifting.log.0, and logShifting.log.1
shiftAge = 3
# Shift log file about for each 1024 bytes.
shiftSize = 1024

log = Devel::Logger.new( logFile, shiftAge, shiftSize )

def doLog( log )
  log.debug( 'doLog1' ) { 'd' * rand( 100 ) }
  log.info( 'doLog2' ) { 'i' * rand( 100 ) }
  log.warn( 'doLog3' ) { 'w' * rand( 100 ) }
  log.error( 'doLog4' ) { 'e' * rand( 100 ) }
  log.caution( 'doLog5' ) { 'c' * rand( 100 ) }
  log.fatal( 'doLog6' ) { 'f' * rand( 100 ) }
  log.unknown( 'doLog7' ) { 'u' * rand( 100 ) }
end

( 1..10 ).each do
  doLog( log )
end

puts 'See logShifting.* in "logs" directory.'
