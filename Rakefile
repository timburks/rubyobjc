#
# Rakefile
#
# RubyObjC top-level Rakefile.  Use this to build, test, and install RubyObjC.
#
#  rake build       builds the bridge
#  rake test        runs the Test::Unit tests in the test directory
#  rake gem         builds a gem
#  rake install     installs the gem
#  -- read the source below, there's more!
#
# Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
# For more information about this file, visit http://www.rubyobjc.com.

require 'rake'

##############################################
# Cleanup

require 'rake/clean'
CLEAN.include(FileList["test/*.bundle"])
CLEAN.include(".gdb_history")
CLOBBER.include("release")
CLOBBER.include("doc")
CLOBBER.include("*.gem")
task :clobber do |t|
  system "cd objc; rake #{t}"
  system "cd app; rake #{t}"
  examples = `ls -d examples/*`.split("\n")
  examples.each {|dir| system "cd #{dir.chomp}; rake #{t}" }
end

task :clean do |t|
  system "cd objc; rake #{t}"
  system "cd app; rake #{t}"
  examples = `ls -d examples/*`.split("\n")
  examples.each {|dir| system "cd #{dir.chomp}; rake #{t}" }
end

##############################################
# Building

task :build do |t|
  system "cd objc; rake #{t}"
end

task :default => :build

##############################################
# Testing
task :test => [:build, :testobject, :teststructs, :testspeed, :testmemory] do
  system "ruby -rtest/unit -e0 -- -v --pattern '/test_.*\.rb^/'"
end

task :teststructs => "test/teststructs.bundle"

task :testobject => "test/testobject.bundle"

task :testspeed => "test/testspeed.bundle"

task :testmemory => "test/testmemory.bundle"

rule ".bundle" => [".m"] do |t|
  sh "gcc #{t.source} -lobjc -framework Foundation -bundle -o #{t.name} -undefined dynamic_lookup"
end

task :base => [:testobject, :build] do
  system "ruby test/test_objc.rb"
end

task :subclasses => [:testobject, :build] do
  system "ruby test/test_subclasses.rb"
end

task :functions => [:testobject, :build] do
  system "ruby test/test_functions.rb"
end

task :structs => [:teststructs, :build] do
  system "ruby test/test_structs.rb"
end

task :speed => [:testspeed, :build] do
  system "ruby test/test_speed.rb"
end

task :memory => [:testmemory, :build] do
  system "ruby test/test_memory.rb"
end

##############################################
# Documentation

require 'rake/rdoctask'

Rake::RDocTask.new do |rdoc|
  files = ['objc', 'ruby/objc.rb', 'ruby/nibtools.rb', 'INTRODUCTION', 'USAGE', 'LICENSE', 'COPYING']
  rdoc.rdoc_files.add(files)
  rdoc.main = 'INTRODUCTION' # page to start on
  rdoc.title = 'RubyObjC'
  rdoc.template = 'tools/egg/rubyobjc.rb'
  rdoc.rdoc_dir = 'doc' # rdoc output folder
  #rdoc.options << '--line-numbers' << '--inline-source'
end

task :publish => :rdoc do
  system "scp -r doc www.rubyobjc.com:Services/rubyobjc/public"
end

task :undoc do
  system "rm -rf doc"
end

task :republish => [:undoc, :publish]

##############################################
# Release

task :release => :gem do
  system "scp RubyObjC-*.gem www.rubyobjc.com:Services/rubyobjc/public/gems"
end

##############################################
# Gems

require 'rubygems'
require 'rubygems/builder'

spec = Gem::Specification.new do |spec|
  spec.name = "RubyObjC"
  spec.summary = "A bridge between Ruby and Objective-C"
  spec.description = "RubyObjC allows Ruby and Objective-C code to be easily mixed.  Among its benefits, it allows developers to write Cocoa applications in pure Ruby."
  spec.author = "Tim Burks"
  spec.email = "tim@neontology.com"
  spec.homepage = "http://www.rubyobjc.com/doc"
  spec.files = Dir['bin/*'] + Dir['lib/**/*'] + ['app/Rakefile'] + Dir['libffi/LICENSE'] + Dir['app/*.icns'] + Dir['app/*.rb'] + Dir['app/*.lproj/**/*'] + ['INTRODUCTION', 'COPYING', 'USAGE']
  spec.version = '0.4.0'
  spec.bindir = 'bin'
  spec.executables = ["rubyapp"]
end

task :gem => [:build] do
  builder = Gem::Builder.new(spec).build
end

##############################################
# Installation

task :install => :gem do
  system "sudo gem install RubyObjC-*.gem"
end

task :uninstall do
  system "sudo gem uninstall RubyObjC"
end

# Examples

EXAMPLES = %w{rubyrocks raiseman maildemo}

task :examples do
  EXAMPLES.each do |example|
    system "cd examples/#{example}; rake clobber"
    system "cd examples; tar zc -f #{example}.tgz --exclude .svn #{example}"
  end
end

task :publish_examples => :examples do
  EXAMPLES.each do |example|
    system "scp examples/#{example}.tgz www.rubyobjc.com:Services/rubyobjc/public/examples"
  end
end
