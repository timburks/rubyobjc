# 
# test_structs.rb
# 
# Tests RubyObjC support for bridged structures.
#
# Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
# For more information about this file, visit http://www.rubyobjc.com.
#

require 'test/unit'
require 'test/teststructs'
require 'lib/objc'

def assert_arrays_in_delta(a, b, delta, message=nil)
  a.size.times{|i|
    assert_in_delta(a[i], b[i], delta, message)
  }
end

class Array
  def scaleBy(scale)
    map{|x| scale*x}
  end
end

class ObjC::StructTester
  use "rubyScaleSize:by:", "{_NSSize=ff}@:{_NSSize=ff}f"
  def rubyScaleSize_by_(size, scale)
    #puts "rubyScaleSize(#{size.inspect})"
    result = size.scaleBy(scale)
    #puts "produced #{result.inspect}"
    result
  end

  use "rubyScalePoint:by:", "{_NSPoint=ff}@:{_NSPoint=ff}f"
  def rubyScalePoint_by_(point, scale)
    #puts "rubyScalePoint(#{point.inspect})"
    result = point.scaleBy(scale)
    #puts "produced #{point.inspect}"
    result
  end

  use "rubyScaleRect:by:", "{_NSRect={_NSPoint=ff}{_NSSize=ff}}@:{_NSRect={_NSPoint=ff}{_NSSize=ff}}f"
  def rubyScaleRect_by_(rect, scale)
    $result = rect.scaleBy(scale)
    #puts "rubyScaleRect(#{rect.inspect}, #{scale}) produced #{result.inspect}"
    $result
  end

  use "rubyScaleRange:by:", "{_NSRange=II}@:{_NSRange=II}f"
  def rubyScaleRange_by_(range, scale)
    #puts "rubyScaleRange(#{range.inspect})"
    result = range.scaleBy(scale)
    #puts "produced #{result.inspect}"
    result
  end
end

#
# Ruby calls Objective-C, which in turn calls Ruby to scale the specified objects
#
class TestObjCStructs < Test::Unit::TestCase
  def test_structs
    tester = ObjC::StructTester.alloc.init

    delta = 0.00001

    size = [2,4]; s = 2
    assert_arrays_in_delta(size.scaleBy(s), tester.scaleSize_by_(size, s), delta)

    size = [2.0,4.0]; s = 3.1415927**2
    assert_arrays_in_delta(size.scaleBy(s), tester.scaleSize_by_(size, s), delta)

    point = [1,2]; s = 4
    assert_arrays_in_delta(point.scaleBy(s), tester.scalePoint_by_(point, s), delta)

    point = [2.0,4.0]; s = 3.1415
    assert_arrays_in_delta(point.scaleBy(s), tester.scalePoint_by_(point, s), delta)
    rect = [1,1,1,1]; s = 2
#   assert_arrays_in_delta(rect.scaleBy(s), tester.scaleRect_by_(rect, s), delta)

    rect = [1,2,3,4]; s = 32.1
#   assert_arrays_in_delta(rect.scaleBy(s), tester.scaleRect_by_(rect, s), delta)
    range = [1,2]; s = -10
#   assert_arrays_in_delta(range.scaleBy(s), tester.scaleRange_by_(range, s), delta)

    scaleSize = ObjC::Function.wrap("scaleSize", "{_NSSize=ff}", ["{_NSSize=ff}", "f"])

    size = [3,4]; s = 2
    assert_arrays_in_delta(size.scaleBy(s), scaleSize.call(size, s), delta)

    size = [2.0, 4.0]
    assert_arrays_in_delta(size.scaleBy(s), scaleSize.call(size, s), delta)

    scaleRect = ObjC::Function.wrap("scaleRect", "{_NSRect={_NSPoint=ff}{_NSSize=ff}}", ["{_NSRect={_NSPoint=ff}{_NSSize=ff}}", "f"])
    rect = [1,2,3,4]; s = 32.1
    assert_arrays_in_delta(rect.scaleBy(s), scaleRect.call(rect, s), delta)
  end
end
