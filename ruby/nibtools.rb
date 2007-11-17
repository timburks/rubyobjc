# 
# nibtools.rb
# 
# Ruby tools for working with the contents of nib files.
# This file is compiled into the RubyObjC library as an optional component.
# It is loaded when the <b>nibtools</b> module is loaded using <b>ObjC.require :nibtools</b>.
#
# Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
# For more information about this file, visit http://www.rubyobjc.com.
#

def __filter_for_display(object) # :nodoc:
  if object.kind_of?(ObjC::NSString)
    object.to_s
  else
    object
  end
end

class ObjC::NSObject
  def children # :nodoc:
    []
  end
  def attributes # :nodoc:
    [:class]
  end
  def dump(level="") # :nodoc:
    puts level+attributes.map{|a| {a => __filter_for_display(self.send(a))}}.inspect
    self.children.each {|child| child.dump(level+"  ")}
  end
  # Return all of the objects in the object hierarchy rooted at the current object that match criteria in the provided hash.
  # For example, to return all the NSButton objects in a specified view, use:
  #    buttons = myView.all(:class => ObjC::NSButton)
  # Requires the *nibtools* extension.
  def all(attributes)
    match = true
    attributes.each_pair do |key, value|
      if self.respond_to?(key)
        v = self.send(key)
        v = v.to_s if v.kind_of? ObjC::NSString
        match = false if (v != value)
      else
        match = false
      end
    end
    matches = []
    matches << self if match
    children.each do |child|
      matches += child.all(attributes)
    end
    matches
  end
  # Return the one object in the object hierarchy rooted at the current object that matches criteria in the provided hash.
  # Raise an exception if there is not exactly one match.
  # For example, to return the NSButton object in a specified view with tag of '2', use:
  #    buttons = myView.only(:class => ObjC::NSButton, :tag => 2)
  # Requires the *nibtools* extension.
  def only(attributes)
    matches = all(attributes)
    if matches.length == 1
      matches[0]
    elsif matches.length == 0
      raise "no items found with #{attributes.inspect}"
    else
      raise "#{matches.length} items found with #{attributes.inspect}"
    end
  end
end

class ObjC::NSBox # :nodoc:
  def attributes
    super + [:contentViewMargins]
  end
end

class ObjC::NSButton # :nodoc:
  def attributes
    super + [:bezelStyle, :isBordered, :title, :tag]
  end
end

class ObjC::NSControl # :nodoc:
  def children
    super + (self.font ? [self.font] : [])
  end
end

class ObjC::NSFont # :nodoc:
  def attributes
    super + [:fontName, :pointSize]
  end
end

class ObjC::NSScrollView # :nodoc:
  def attributes
    super + [:hasHorizontalScroller, :hasVerticalScroller, :borderType]
  end
end

class ObjC::NSTableColumn # :nodoc:
  def attributes
    super + [:identifier, :width, :resizingMask]
  end
end

class ObjC::NSTableView # :nodoc:
  def attributes
    super + [:allowsColumnResizing, :columnAutoresizingStyle]
  end
  def children
    super + self.tableColumns.to_a
  end
end

class ObjC::NSTextField # :nodoc:
  def attributes
    super + [:stringValue, :drawsBackground, :tag]
  end
end

class ObjC::NSView # :nodoc:
  def children
    super + subviews.to_a
  end
  def attributes
    super + [:frame, :autoresizingMask]
  end
end

class ObjC::NSWindow # :nodoc:
  def attributes
    super + [:frame, :title, :minSize, :maxSize]
  end
  def children
    super + [self.contentView]
  end
end

class ObjC::NSWindowController # :nodoc:
  def children
    super + (self.window ? [self.window] : [])
  end
end

class ObjC::NSApplication # :nodoc:
  def children
    super + (self.mainMenu ? [self.mainMenu] : []) + windows.to_a
  end
end

class ObjC::NSMenu # :nodoc:
  def attributes
    super + [:title]
  end
  def children
    super + self.itemArray.to_a
  end
end

class ObjC::NSMenuItem # :nodoc:
  def attributes
    super + [:title]
  end
  def children
    super + (self.submenu ? [self.submenu] : [])
  end
end
