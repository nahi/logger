#!/usr/bin/env ruby

require "rbconfig"
require "ftools"
include Config

RV = CONFIG["MAJOR"] + "." + CONFIG["MINOR"]
DSTPATH = CONFIG["sitedir"] + "/" +  RV 

def join( *arg )
  File.join( *arg )
end

def base( name )
  File.basename( name )
end

begin
  unless FileTest.directory?( "lib" )
    raise RuntimeError.new( "'lib' not found." )
  end
  unless FileTest.directory?( join( "lib", "devel" ))
    raise RuntimeError.new( "'lib/devel' not found." )
  end

  File.mkpath( join( DSTPATH, "devel" ), true )
  Dir[ 'lib/devel/*.rb' ].each do | name |
    File.install( name, join( DSTPATH, 'devel', base( name )), 0644, true )
  end
  Dir[ 'lib/*.rb' ].each do | name |
    File.install( name, join( DSTPATH, base( name )), 0644, true )
  end

  puts "install succeed!"

rescue 
  puts "install failed!"
  puts $!
end
