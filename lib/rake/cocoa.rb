#
# cocoa.rb
#
# Rake tasks for RubyObjC projects.
# Use them to build and test applications and bundles that use RubyObjC.
#
# Typical usage:
# -----------------------------------------------
# require 'rake/cocoa'
#
# Rake::CocoaApplication.new do |t|
#   t.application = "My Application"
#   t.identifier = 'com.rubyobjc.myapp'
#   t.icon_file = 'myapp.icns'
# end
# -----------------------------------------------
#
# See the RubyObjC example projects for more examples,
# or just read the source below.
#
# Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
# For more information about this file, visit http://www.rubyobjc.com.

require 'rake'
require 'rake/clean'
require 'rake/tasklib'

LIBDIR = File.dirname(__FILE__) + '/..'
BASEAPP = LIBDIR + '/rubyobjcapp'

module Rake
  class CocoaTask < TaskLib

    # helper function used by both applications and bundles
    def generate_compilation_tasks
      # source files must be in appropriate subdirectories ('objc', 'ruby', or 'resources')
      @erb_headers  = FileList['objc/*.rh']
      @erb_files    = FileList['objc/*.rm']
      @bison_files  = FileList['objc/*.y']
      @flex_files   = FileList['objc/*.l']
      @c_files      = FileList['objc/*.c']
      @objc_files   = FileList['*.m'] + FileList['objc/*.m']

      @gcc_files   = @objc_files + @c_files + @erb_files.sub(/\.r/, '.') + @bison_files.sub(/\.y$/, '.m') + @flex_files.sub(/\.l$/, '.m')
      @gcc_objects = @gcc_files.sub(/\.c$/, '.o').sub(/\.m$/, '.o').uniq

      @nib_files    = FileList['English.lproj/*.nib'] + FileList['resources/English.lproj/*.nib']
      @icon_files   = FileList['*.icns']              + FileList['resources/*.icns']

      @cc = "gcc"
      @includes = %w{RubyCocoa Ruby}.map {|f| " -I/System/Library/Frameworks/#{f}.framework/Headers"}.join
      #@ldflags += " -isysroot /Developer/SDKs/MacOSX10.4u.sdk"
      @ldflags += @frameworks.map {|framework| " -framework #{framework}"}.join
      @ldflags += @libs.map {|lib| " -l#{lib}"}.join
      @ldflags += @lib_dirs.map {|libdir| " -L#{libdir}"}.join + " -L#{LIBDIR}"
     

      # default task for generated code, define it here in case there is none needed
      task :generated

      @generated_files = FileList.new

      # remove all generated files
      task :remove_generated do
        sh "rm #{@generated_files}"
      end

      # rebuild all generated files
      task :regenerate => [:remove_generated, :generated]

      # ERB code generators for Objective-C code
      (@erb_headers + @erb_files).each {|template|
        generated = template.sub(/\.r/, '.')
        task :generated => generated
        file generated => template do |t|
          sh "cd objc; erb #{File.basename(template)} > #{File.basename(generated)}"
        end
        CLOBBER.include(generated)
        @generated_files.include(generated)
      }

      # YACC grammars
      @bison_files.each {|bisonfile|
        generatedsource = bisonfile.sub(/\.y$/, '.m')
        generatedheader = bisonfile.sub(/\.y$/, '.h')
        file generatedsource => bisonfile
        CLOBBER.include(generatedsource, generatedheader)
        @generated_files.include(generatedsource, generatedheader)
      }

      @bison = File.exist?("/usr/local/bin/bison") ? "/usr/local/bin/bison" : 
               File.exist?("/opt/local/bin/bison") ? "/opt/local/bin/bison" : "/usr/bin/bison"
      @flex = File.exist?("/usr/local/bin/flex") ? "/usr/local/bin/flex" :
              File.exist?("/opt/local/bin/flex") ? "/opt/local/bin/flex" : "/usr/bin/flex"

      rule ".m" => [".y"] do |t|
        basename = t.name.split('.')[0..-2].join('.')
        prefix = t.name.gsub("objc/", "").gsub("Parser.m", "_").downcase
        sh "#{@bison} -d #{t.source} --name-prefix=#{prefix}"
        sh "mv *.tab.* objc"
        sh "mv #{basename}.tab.h #{basename}.h"
        sh "sed -e 's/tab.c/m/' #{basename}.tab.c > #{basename}.m"
        sh "rm #{basename}.tab.c"
      end

      # FLEX lexers
      @flex_files.each {|flexfile|
        generatedsource = flexfile.sub(/\.l$/, '.m')
        file generatedsource => flexfile
        CLOBBER.include(generatedsource)
        @generated_files.include(generatedsource)
      }

      rule ".m" => [".l"] do |t|
        prefix = t.name.gsub("objc/", "").gsub("Lexer.m", "_").downcase
        sh "#{@flex}  -o#{t.name} --prefix=#{prefix} #{t.source}"
      end

      # basic compilation with gcc
      rule ".o" => [".m"] do |t|
        sh "#{@cc} #{@cflags} #{@arch} #{@includes} -c -o #{t.name} #{t.source}"
      end

      rule ".o" => [".c"] do |t|
        sh "#{@cc} #{@cflags} #{@arch} #{@includes} -c -o #{t.name} #{t.source}"
      end
    end
  end

  class CocoaApplication < CocoaTask
    attr_accessor :application, :identifier, :icon_file, :frameworks, :info, :cflags, :ldflags, :resources, :arch

    def initialize
      @name = :app
      @application = "RubyObjC"
      @identifier = 'com.rubyobjc.app'
      @icon_file = ''
      @creator_code = '????'
      @info = nil
      @resources = []

      @arch = "-arch i386 -arch ppc"  # build universal apps by default
      @cflags = "-g -Wall"

      @frameworks = %w{Cocoa}
      @libs = %w{objc rubyobjc }
      @lib_dirs = []
      if File.exist? "/usr/lib/libffi.dylib"
        @libs << "ffi"
        @lib_dirs << "/usr/lib"
      end
      @ldflags = ""

      if @gcc_objects != []
        if File.exist? "/System/Library/Frameworks/Ruby.framework"
          @frameworks << "Ruby"
        else
          @libs << "ruby-static"
          if File.exist? "/usr/local/lib/libruby-static.a"
            @lib_dirs << "/usr/local/lib"
          elsif File.exist? "/opt/local/lib/libruby-static.a"
            @lib_dirs << "/opt/local/lib" # macports
            @arch = "" # macports are never universal
          else
            raise "can't find Ruby.framework or libruby-static.a"
          end
        end
      end

      yield self if block_given?

      @app_dir         = "#{@application}.app"
      @contents_dir    = "#{@app_dir}/Contents"
      @executable_dir  = "#{@contents_dir}/MacOS"
      @resource_dir    = "#{@contents_dir}/Resources"
      @localized_dir   = "#{@contents_dir}/Resources/English.lproj"
      FileList[@app_dir, @contents_dir, @executable_dir, @resource_dir, @localized_dir].each {|d| directory d}

      task :default => :app

      desc "Build the application."
      task :app => [:executable, :resources, :info_plist, :pkginfo]

      desc "Run the application."
      task :run => :app do
        sh "open '#{@application}.app'"
      end

      desc "Debug the application by running it from the console; log messages will be displayed in the terminal."
      task :debug => :app do
        sh "'#{@executable_dir}/#{@application}'"
      end

      desc "Debug the application with gdb."
      task :gdb => :app do
        sh "gdb '#{@executable_dir}/#{@application}'"
      end

      desc "Build a disk image for distributing the application."
      task :dmg => :app do
        sh "rm -rf '#{@application}.dmg' dmg"
        sh "mkdir dmg; cp -r '#{@application}.app' dmg"
        sh "hdiutil create -srcdir dmg '#{@application}.dmg' -volname '#{@application}'"
        sh "rm -rf dmg"
      end

      generate_compilation_tasks

      @ruby_files = File.exist?("ruby") ? FileList['ruby/*.rb'] : FileList['*.rb']
      @nu_files = File.exist?("nu") ? FileList['nu/*.nu'] : FileList['*.nu']

      desc "Create the executable (subtask of app)."
      task :executable  => [:generated, @executable_dir, "#{@executable_dir}/#{@application}"]
      if @gcc_objects == []
        file "#{@executable_dir}/#{@application}" => BASEAPP do |t|
          sh "cp #{BASEAPP} '#{t.name}'"
          sh "chmod +x '#{t.name}'"
        end
      else
        file "#{@executable_dir}/#{@application}" => @gcc_objects do |t|
          sh "#{@cc} #{@gcc_objects} #{@cflags} #{@arch} #{@ldflags} -o '#{t.name}'"
        end
      end

      desc "Copy files to the application's Resources directory (subtask of app)."
      task :resources   => [@resource_dir, :infoplist_strings, :mainmenu]
      [@ruby_files, @nu_files, @icon_files, @resources].each{|list| list.each {|f|
      task :resources => "#{@resource_dir}/#{f.split("/")[-1]}"
    file "#{@resource_dir}/#{f.split("/")[-1]}" => f do |t|
      cp_r f, t.name
    end
  }}

  @nib_files.each {|f|
    g = f.split('/')[-1]
    task :resources => "#{@localized_dir}/#{g}"
    file "#{@localized_dir}/#{g}" => f do |t|
      cp_r "English.lproj/#{g}", t.name
    end
  }

  desc "Copy the default MainMenu.nib file, if necessary."
  task :mainmenu => @localized_dir do |t|
    cp_r LIBDIR+"/resources/English.lproj/MainMenu.nib", @localized_dir+"/MainMenu.nib" unless File.exist? "English.lproj/MainMenu.nib"
  end

  desc "Copy the default InfoPlist.strings file, if necessary."
  task :infoplist_strings => @localized_dir do |t|
    cp_r LIBDIR+"/resources/English.lproj/InfoPlist.strings", @localized_dir+"/InfoPlist.strings"
  end

  if File.exist?("lib")
    task :resources => "#{@resource_dir}/lib"
    file "#{@resource_dir}/lib" => "lib" do |t|
      sh "rm -rf #{t.name}"
      cp_r "lib", t.name
    end
  end

  desc "Create the Info.plist file (subtask of app)."
  task :info_plist  => [@contents_dir, "#{@contents_dir}/Info.plist"]
  file "#{@contents_dir}/Info.plist" do |t|
    info = {
      :CFBundleDevelopmentRegion => "English",
      :CFBundleExecutable => @application,
      :CFBundleIconFile => @icon_file,
      :CFBundleIdentifier => @identifier,
      :CFBundleInfoDictionaryVersion => "6.0",
      :CFBundleName => @application,
      :CFBundlePackageType => "APPL",
      :CFBundleSignature => @creator_code,
      :CFBundleVersion => "1.0",
      :NSMainNibFile => "MainMenu",
      :NSPrincipalClass => "NSApplication"
    }
    info = info.merge(@info) if @info
    plist = PList.generate(info)
    File.open(t.name, "w") {|f| f.write plist}
  end

  desc "Create the PkgInfo file (subtask of app)."
  task :pkginfo     => [@contents_dir, "#{@contents_dir}/PkgInfo"]
  file "#{@contents_dir}/PkgInfo" do |t|
    sh "echo -n 'APPL#{@creator_code}' > '#{t.name}'"
  end

  CLEAN.include("**/*.o")                             # all object files
  CLOBBER.include("*.lproj/*~.nib")			              # backup nib files
  CLOBBER.include("#{@app_dir}")                      # the application
  CLOBBER.include(".gdb_history")                     # support files

  if @gcc_objects != []
    desc "Create a bundle containing all objc sources; bundles can be loaded for testing and debugging in Ruby."
    task :bundle => [:generated, "#{@application.downcase}.bundle"]
    file "#{@application.downcase}.bundle" => @gcc_objects do |t|
      sh "#{@cc} #{@gcc_objects} #{@cflags} #{@arch} #{@ldflags} -o '#{@application.downcase}.bundle' -bundle"
    end
  end
end
end

class CocoaBundle < CocoaTask
attr_accessor :bundle, :identifier, :icon_file, :frameworks, :info, :cflags, :ldflags, :resources, :arch

def initialize
  @name = :bundle
  @bundle = "RubyObjC"
  @identifier = 'com.rubyobjc.bundle'
  @info = nil
  @resources = []

  @arch = "-arch i386 -arch ppc"  # build universal by default
  @cflags = "-g -Wall"

  @frameworks = %w{Cocoa}
  @libs = %w{objc}
  @lib_dirs = []
  @ldflags = ""

  yield self if block_given?

  task :default => :bundle

  desc "Build the bundle."
  task :bundle => [:executable, :resources, :info_plist, :pkginfo]

  @bundle_dir      = "#{@bundle}.bundle"
  @contents_dir    = "#{@bundle_dir}/Contents"
  @executable_dir  = "#{@contents_dir}/MacOS"
  @resource_dir    = "#{@contents_dir}/Resources"
  @localized_dir   = "#{@contents_dir}/Resources/English.lproj"

  FileList[@bundle_dir, @contents_dir, @executable_dir, @resource_dir, @localized_dir].each {|d| directory d}

  generate_compilation_tasks

  @ruby_files = File.exist?("ruby") ? FileList['ruby/*.rb'] : FileList['*.rb']
  @nu_files = File.exist?("nu") ? FileList['nu/*.nu'] : FileList['*.nu']

  desc "Create the executable (subtask of bundle)."
  task :executable  => [:generated, @executable_dir, "#{@executable_dir}/#{@bundle}"]
  file "#{@executable_dir}/#{@bundle}" => @gcc_objects do |t|
    sh "#{@cc} #{@gcc_objects} #{@c_objects} #{@cflags} #{@arch} #{@ldflags} -o '#{t.name}' -bundle"
  end

  desc "Copy files to the bundle's Resources directory (subtask of bundle)."
  task :resources   => [@resource_dir]
  [@ruby_files, @nu_files, @icon_files, @resources].each{|list| list.each {|f|
  task :resources => "#{@resource_dir}/#{f.split("/")[-1]}"
file "#{@resource_dir}/#{f.split("/")[-1]}" => f do |t|
  cp_r f, t.name
end
}}

@nib_files.each {|f|
g = f.split('/')[-1]
task :resources => "#{@localized_dir}/#{g}"
file "#{@localized_dir}/#{g}" => f do |t|
  cp_r "English.lproj/#{g}", t.name
end
}

if File.exist?("lib")
task :resources => "#{@resource_dir}/lib"
file "#{@resource_dir}/lib" => "lib" do |t|
  sh "rm -rf #{t.name}"
  cp_r "lib", t.name
end
end

desc "Create the Info.plist file (subtask of bundle)."
task :info_plist  => [@contents_dir, "#{@contents_dir}/Info.plist"]
file "#{@contents_dir}/Info.plist" do |t|
info = {
  :CFBundleDevelopmentRegion => "English",
  :CFBundleExecutable => @bundle,
  :CFBundleIdentifier => @identifier,
  :CFBundleInfoDictionaryVersion => "6.0",
  :CFBundleName => @bundle,
  :CFBundlePackageType => "BNDL",
  :CFBundleSignature => @creator_code,
  :CFBundleVersion => "1.0",
  :NSPrincipalClass => @bundle
}
info = info.merge(@info) if @info
plist = PList.generate(info)
File.open(t.name, "w") {|f| f.write plist}
end

desc "Create the PkgInfo file (subtask of bundle)."
task :pkginfo     => [@contents_dir, "#{@contents_dir}/PkgInfo"]
file "#{@contents_dir}/PkgInfo" do |t|
sh "echo -n 'APPL#{@creator_code}' > '#{t.name}'"
end

desc "Test the bundle."
task :test => :bundle do
system "ruby -rtest/unit -e0 -- -v --pattern '/test_.*\.rb^/'"
end

CLEAN.include("**/*.o")                             # all object files
CLOBBER.include("*.lproj/*~.nib")			              # backup nib files
CLOBBER.include("#{@bundle_dir}")                      # the application
CLOBBER.include(".gdb_history")                     # support files
end
end

end

# Helper module for generating plists.
module PList
TAB = "    "
def self.value(object, indent="")
if object.class == Hash
result = "#{indent}<dict>\n"
object.keys.sort_by{|k| k.to_s}.each {|key|
result += "#{indent}#{TAB}<key>#{key}</key>\n"
result += value(object[key], indent+TAB)
}
result += "#{indent}</dict>\n"
elsif object.class == Array
result = "#{indent}<array>\n"
result += object.map {|item| value(item, indent+TAB)}.join("")
result += "#{indent}</array>\n"
else
result = "#{indent}<string>#{object}</string>\n"
end
result
end
def self.generate(info)
plist = '<?xml version="1.0" encoding="UTF-8"?>' + "\n"
plist += '<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' + "\n"
plist += '<plist version="1.0">' + "\n"
plist += value(info)
plist += "</plist>\n"
plist
end
end
