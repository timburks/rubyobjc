# 
# test_wrappers.rb
# 
# Tests RubyObjC wrappers of Objective-C classes.
#
# Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
# For more information about this file, visit http://www.rubyobjc.com.
#

require 'test/unit'
require 'lib/objc'

class TestWrappers < Test::Unit::TestCase
  def test_array
    array = ObjC::NSMutableArray.alloc.init
    array << 0
    array << "one"
    array << 2.0
    assert_equal(3, array.length)
    assert_equal(0, array[0].to_i)
    assert_equal("one", array[1].to_s)
    assert_equal(2.0, array[2].to_f)
    assert_equal([1,1,1], array.map {|x| 1}) # verifies that the NSArray is Enumerable
  end
  
  def test_dictionary
    dictionary = ObjC::NSMutableDictionary.alloc.init
    dictionary[1] = "one"
    dictionary["two"] = 2
    assert_equal("one", dictionary[1].to_s)
    assert_equal(2, dictionary["two"].to_i)
    assert_equal(2, dictionary.keys.length)
    assert_equal(2, dictionary.values.length)
  end
end
