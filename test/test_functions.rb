# 
# test_functions.rb
# 
# Tests RubyObjC function wrappers.
#
# Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
# For more information about this file, visit http://www.rubyobjc.com.
#

require 'test/unit'
require 'lib/objc'
require 'test/testobject'

class TestObjCFunctions < Test::Unit::TestCase
  def test_wrap
    cadd = ObjC::Function.wrap("cadd", "c", ["c", "c"])
    assert_equal 7, cadd.call(4, 3)
    assert_equal 4, cadd.call(7, -3)

    ucadd = ObjC::Function.wrap("ucadd", "C", ["C", "C"])
    assert_equal 7, ucadd.call(4, 3)
    assert_equal 4, ucadd.call(7, -3)

    iadd = ObjC::Function.wrap("iadd", "i", ["i", "i"])
    assert_equal 5, iadd.call(2, 3)
    assert_equal 4, iadd.call(7, -3)

    uiadd = ObjC::Function.wrap("uiadd", "I", ["I", "I"])
    assert_equal 5, uiadd.call(2, 3)
    assert_equal 4, uiadd.call(7, -3)

    ladd = ObjC::Function.wrap("ladd", "l", ["l", "l"])
    assert_equal 50, ladd.call(30, 20)
    assert_equal 4, ladd.call(7, -3)

    uladd = ObjC::Function.wrap("uladd", "L", ["L", "L"])
    assert_equal 5, uladd.call(2, 3)
    assert_equal 4, uladd.call(7, -3)

    qadd = ObjC::Function.wrap("qadd", "q", ["q", "q"])
    assert_equal 160, qadd.call(70, 90)
    assert_equal 40, qadd.call(70, -30)

    uqadd = ObjC::Function.wrap("uqadd", "Q", ["Q", "Q"])
    assert_equal 5, uqadd.call(2, 3)
    assert_equal 40, uqadd.call(70, -30)

    dadd = ObjC::Function.wrap("dadd", "d", ["d", "d"])
    assert_equal 6.8, dadd.call(2.3, 4.5)

    ObjC.add_function iadd
    assert_equal 5, ObjC.iadd(2, 3)

    dadd >> ObjC
    assert_equal 6.8, ObjC.dadd(2.3, 4.5)

    ObjC.add_function ObjC::Function.wrap("testFunction", "*", ["i", "^*"])
    assert_equal "onetwothree", ObjC.testFunction(3, ["one", "two", "three"])
    assert_equal "", ObjC.testFunction(0, nil)

    itwo = ObjC::Function.wrap("itwo", "i", nil)
    assert_equal 2, itwo.call()

  end
end
