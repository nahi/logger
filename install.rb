#!/usr/bin/env ruby

require "rbconfig"
require "ftools"
include Config

RV = CONFIG["MAJOR"] + "." + CONFIG["MINOR"]
DSTPATH = CONFIG["sitedir"] + "/" +  RV 

begin
  unless FileTest.directory?( "lib" )
    raise RuntimeError.new( "'lib' not found." )
  end
  unless FileTest.directory?( File.join( "lib", "devel" ))
    raise RuntimeError.new( "'lib/devel' not found." )
  end

  File.mkpath DSTPATH + "/devel", true 

  name = File.join( 'lib', 'devel', 'logger.rb' )
  File.install( name, File.join( DSTPATH, 'devel', File.basename( name )),
    0644, true )

rescue 
  puts "install failed!"
  puts $!
else
  puts "install succeed!"
end
