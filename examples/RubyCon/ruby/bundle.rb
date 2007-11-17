#
#  RubyCon
#  bundle.rb
#
# Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
# For more information about this file, visit http://www.rubyobjc.com.
#
ObjC.set_path :LOCAL
ObjC.require :foundation, :appkit, :console

class RubyObjC_ConsoleController < ObjC::NSObject
  imethod "showConsole:" do |sender|
    ObjC::Console.display({:exits => false})
  end

  def install
    with (ObjC::NSMenuItem.alloc.initWithTitle_action_keyEquivalent_("Console", "showConsole:", "`")) do |i|
      i.setTarget_(self)
      with (ObjC::NSMenu.alloc.initWithTitle_ "Ruby") do |m|
        m.insertItem_atIndex_(i, 0)
        with(ObjC::NSMenuItem.alloc.initWithTitle_action_keyEquivalent_("Ruby", nil, "")) do |i2|
          i2.setSubmenu_ m
          ObjC::NSApp.mainMenu.insertItem_atIndex_(i2, ObjC::NSApp.mainMenu.numberOfItems)
        end
      end
    end
  end
end

$cc = RubyObjC_ConsoleController.alloc.init
$cc.install
