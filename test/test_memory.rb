# 
# test_memory.rb
# 
# Tests RubyObjC memory management.
#
# Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
# For more information about this file, visit http://www.rubyobjc.com.
#

require 'test/unit'
require 'lib/objc'
require 'test/testmemory'

class MyString < ObjC::NSObject
  use "initWithString:", "@@:@"
  def initWithString_(s)
    init
    @string = s.to_s
    self
  end
  def string
    @string
  end
end

N = 10

class TestMemory < Test::Unit::TestCase

  # objects created from Ruby and owned by Objective-C objects must be preserved through GC
  def test_gc_from_ruby
    array = ObjC::NSMutableArray.alloc.init
    100.times {|i|
      array.addObject_(MyString.alloc.initWithString_("thing #{i}"))
    }
    GC.start
    array.each_with_index {|thing, i|
      assert_equal "thing #{i}", thing.string if i > (100-N)
    }
  end

  # objects created from Objective-C and owned by Objective-C objects must be preserved through GC
  def test_gc_from_objc
    tester = ObjC::MemoryTester.alloc.init
    tester.createObjects_(N)
    GC.start
    N.times {|i|
      assert_equal "item #{i}", tester.objectAtIndex_(i).string
    }
  end
end
