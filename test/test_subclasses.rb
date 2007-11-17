# 
# test_subclasses.rb
# 
# Tests RubyObjC subclassing of Objective-C classes.
#
# Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
# For more information about this file, visit http://www.rubyobjc.com.
#

require 'test/unit'
require 'test/testobject'
require 'lib/objc'

class Stack < ObjC::NSMutableArray
  use :customInit, "@@:"
  def customInit
    s = init
    puts "custom init"
    s.addObject_(1)
    s.addObject_(2)
    self
  end

  use :hello, "@@:"
  def hello
    "hello Brad, this is Matz"
  end

  use :two, "i@:"
  def two
    2
  end

  use "add:plus:", "i@:ii"
  def add_plus_(x,y)
    #puts "x=#{x}, y=#{y}"
    x+y
  end

  use "fadd:plus:", "f@:ff"
  def fadd_plus_(x,y)
    #puts "x=#{x}, y=#{y}"
    x+y
  end

  use "dadd:plus:", "d@:dd"
  def dadd_plus_(x,y)
    #puts "x=#{x}, y=#{y}"
    x+y
  end

  use "objectAtIndex:", "@@:i"
  def objectAtIndex_(index)
    "object at #{index}"
  end
end

class TestObjCSubclasses < Test::Unit::TestCase
  def test_subclasses
    x = ObjC::TestObject.alloc.init
    assert_equal(0, x.testStack)
  end
end
