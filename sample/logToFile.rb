#!/usr/bin/env ruby

$:.unshift(File.join('..', 'lib'))
require 'logger'

logfile = File.join('logs', 'logToFile.log')
log = Logger.new(logfile)

def do_log(log)
  log.debug('do_log1') { "debug" }
  log.info('do_log2') { "info" }
  log.warn('do_log3') { "warn" }
  log.error('do_log4') { "error" }
  log.caution('do_log5') { "caution" }
  log.fatal('do_log6') { "fatal" }
  log.unknown('do_log7') { "unknown" }
end

log.level = Logger::DEBUG	# Default.
do_log(log)

puts "Set severity threshold 'WARN'."

log.level = Logger::WARN
do_log(log)

puts 'See logfile in "logs" directory.'
