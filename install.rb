#!/usr/bin/env ruby

require "rbconfig"
require "ftools"
include Config

RV = CONFIG["MAJOR"] + "." + CONFIG["MINOR"]
RUBYLIBDIR = CONFIG["rubylibdir"]
DSTPATH = CONFIG["sitedir"] + "/" +  RV 

def join(*arg)
  File.join(*arg)
end

def base(name)
  File.basename(name)
end

begin
  name = join('lib', 'logger.rb')
  if RUBY_VERSION >= '1.8.0'
    File.install(name, join(RUBYLIBDIR, base(name)), 0644, true)
  else
    File.install(name, join(DSTPATH, base(name)), 0644, true)
  end

  name = join('lib', 'devel', 'logger.rb')
  File.mkpath(join(DSTPATH, "devel"), true)
  File.install(name, join(DSTPATH, 'devel', base(name)), 0644, true)

  puts "install succeed!"

rescue 
  puts "install failed!"
  puts $!
end
