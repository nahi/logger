#!/usr/bin/env ruby

require "rbconfig"
require "ftools"
include Config

RV = CONFIG["MAJOR"] + "." + CONFIG["MINOR"]
DSTPATH = CONFIG["sitedir"] + "/" +  RV 

def join(*arg)
  File.join(*arg)
end

def base(name)
  File.basename(name)
end

begin
  Dir[ 'lib/*.rb' ].each do | name |
    File.install(name, join(DSTPATH, base(name)), 0644, true)
  end

  puts "install succeed!"

rescue 
  puts "install failed!"
  puts $!
end
