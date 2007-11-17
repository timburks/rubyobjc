#
#  RubyRocks Revisited
#  main.rb
#
# Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
# For more information about this file, visit http://www.rubyobjc.com.
#
ObjC.set_path :INTERNAL
ObjC.require :foundation, :appkit, :menu
ObjC.load_internal_files(__FILE__)

class ApplicationDelegate < ObjC::NSObject
  imethod "applicationDidFinishLaunching:" do |sender|
    make_menu "RubyRocks"
    $r = rubyrocks
  end
end

$delegate = ApplicationDelegate.alloc.init
ObjC::NSApplication.sharedApplication.setDelegate_($delegate)
ObjC::NSApplication.sharedApplication.activateIgnoringOtherApps_(true)
ObjC.NSApplicationMain(0, nil)
