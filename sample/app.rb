#!/usr/bin/env ruby

$:.unshift( File.join( '..', 'lib' ))
require 'devel/logger'

class MyApp < Devel::Application
  def initialize( a, b, c )
    super( 'MyApp' )

    # Set logDevice here.
    logFile = File.join( 'logs', 'app.log' )
    setLog( logFile )
    setSevThreshold( SEV_INFO )

    # Initialize your application...
    @a = a
    @b = b
    @c = c
  end

  def run
    @log.info  { 'Started.' }

    @log.info  { "This block isn't evaled because 'debug' is not severe here." }
    @log.debug { "Result = " << foo( 0 ) }
    @log.info  { "So nothing is dumped." }

    @log.info  { "This block is evaled because 'info' is enough severe here." }
    @log.info  { "Result = " << foo( 0 ) }
    @log.info  { "Above causes exception, so not reached here." }

    @log.info  { 'Finished.' }
  end

private

  def foo( var )
    1 / var
  end
end

status = MyApp.new( 1, 2, 3 ).start

if status != 0
  puts 'Some error(s) occured.'
  puts 'See "app.log" in "logs" directory.'
end
