# 
# test_exceptions.rb
# 
# Tests RubyObjC exception handling.
#
# Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
# For more information about this file, visit http://www.rubyobjc.com.
#

require 'test/unit'
require 'test/testspeed'
require 'lib/objc'

class TestExceptions < Test::Unit::TestCase

  def test_argc
    tester = ObjC::Tester.alloc.init
    assert_raise(RuntimeError) {tester.add_to_}
    assert_raise(RuntimeError) {tester.add_to_(1)}
    assert_raise(RuntimeError) {tester.add_to_(1,2,3)}
  end
end
