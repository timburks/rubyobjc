# 
# menu.rb
# 
# Ruby example for creating and manipulating Cocoa menus.
# This file is compiled into the RubyObjC library as an optional component.
# It is loaded when the <b>menu</b> module is loaded using <b>ObjC.require :menu</b>.
#
# Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
# For more information about this file, visit http://www.rubyobjc.com.
#

module MenuMaker
  @@context = []
  def _context
    @@context[-1]
  end
  def separator
    _context.insertItem_atIndex_(ObjC::NSMenuItem.separatorItem, _context.numberOfItems)
  end
  def item(name)
    i = ObjC::NSMenuItem.alloc.initWithTitle_action_keyEquivalent_(name, nil, "")
    _context.insertItem_atIndex_(i, _context.numberOfItems)
    i
  end
  def menu(name)
    m = ObjC::NSMenu.alloc.initWithTitle_ name
    if _context
      i = ObjC::NSMenuItem.alloc.initWithTitle_action_keyEquivalent_(name, nil, "")
      _context.insertItem_atIndex_(i, _context.numberOfItems)
      i.setSubmenu_ m
    end
    if block_given?
      @@context.push(m)
      yield
      @@context.pop
    end
    m.setAutoenablesItems_ true
    if not _context
      @@mainmenu = m
      ObjC::NSApplication.sharedApplication.setMainMenu_ m
    elsif name == "Window"
      ObjC::NSApplication.sharedApplication.setWindowsMenu_ m
    elsif name == "Services"
      ObjC::NSApplication.sharedApplication.setServicesMenu_ m
    end
    m
  end
  class ObjC::NSMenuItem
    def withAction(action)
      self.setAction_(action)
      self
    end
    def withTarget(target)
      self.setTarget_(target)
      self
    end
    def withKey(key)
      self.setKeyEquivalent_(key)
      self
    end
    def withModifier(modifier)
      self.setKeyEquivalentModifierMask_(modifier)
      self
    end
  end
end

include MenuMaker

def make_menu(appname = "MyApplication")
  menu("Main") do
    menu("#{appname}") do
      item("About #{appname}").withAction("orderFrontStandardAboutPanel:")
      item("Preferences...").withKey(",")
      separator
      menu("Services")
      separator
      item("Hide #{appname}").withAction("hide:").withKey("h")
      item("Hide Others").withAction("hideOtherApplications:").withKey("h").
      withModifier(ObjC::NSAlternateKeyMask + ObjC::NSCommandKeyMask)
      item("Show All").withAction("unhideAllApplications:")
      separator
      item("Quit #{appname}").withAction("terminate:").withKey("q")
    end
    menu("File") do
      item("New")
      item("Open...").withKey("o")
      menu("Open Recent") do
        item("Clear Menu").withAction("clearRecentDocuments:")
      end
      separator
      item("Close").withAction("performClose:").withKey("w")
      item("Save").withKey("s")
      item("Save As...").withKey("S")
      item("Revert")
      separator
      item("Page Setup...").withAction("runPageLayout:").withKey("P")
      item("Print...").withAction("print:").withKey("p")
    end
    menu("Edit") do
      item("Undo").withAction("undo:").withKey("z")
      item("Redo").withAction("redo:").withKey("Z")
      separator
      item("Cut").withAction("cut:").withKey("x")
      item("Copy").withAction("copy:").withKey("c")
      item("Paste").withAction("paste:").withKey("v")
      item("Delete").withAction("delete:")
      item("Select All").withAction("selectAll:").withKey("a")
      separator
      menu("Find") do
        item("Find...").withKey("f")
        item("Find Next").withKey("g")
        item("Find Previous").withKey("d")
        item("Use Selection for Find").withKey("e")
        item("Scroll to Selection").withKey("j")
      end
      menu("Spelling") do
        item("Spelling...").withAction("showGuessPanel:")
        item("Check Spelling").withAction("checkSpelling:")
        item("Check Spelling as You Type").
        withAction("toggleContinuousSpellChecking:")
      end
    end
    menu("Window") do
      item("Minimize").withAction("performMiniaturize:").withKey("m")
      separator
      item("Bring All to Front").withAction("arrangeInFront:")
    end
    menu("Help") do
      item("#{appname} Help").withAction("showHelp:").withKey("?")
    end
  end
end
