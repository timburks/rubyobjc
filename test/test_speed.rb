# 
# test_speed.rb
# 
# Tests RubyObjC performance optimizations.
#
# Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
# For more information about this file, visit http://www.rubyobjc.com.
#

require 'test/unit'
require 'test/testspeed'

require 'lib/objc'

TEST_RUBYCOCOA = false
require 'osx/cocoa' if TEST_RUBYCOCOA

COUNT = 100000

class RubyTester
  def self.add_to_(x,y)
    x+y
  end
end

class TestSpeed < Test::Unit::TestCase

  def test_rubyobjc
    tester = ObjC::Tester.alloc.init
    t0 = Time.now
    COUNT.times do
      tester.add_to_(2,2)
    end
    t1 = Time.now
    print "#{COUNT} method calls in #{t1 - t0}s"
    assert_equal 4, tester.add_to_(2,2)
  end

  def test_ruby
    t0 = Time.now
    COUNT.times do
      RubyTester.add_to_(2,2)
    end
    t1 = Time.now
    print "#{COUNT} method calls in #{t1 - t0}s"
    assert_equal 4, RubyTester.add_to_(2,2)
  end

  if TEST_RUBYCOCOA
    def test_rubycocoa
      tester = OSX::Tester.alloc.init
      t0 = Time.now
      COUNT.times do
        tester.add_to_(2,2)
      end
      t1 = Time.now
      print "#{COUNT} method calls in #{t1 - t0}s"
      assert_equal 4, tester.add_to_(2,2)
    end
  end

  def test_wrap
    add = ObjC::Function.wrap("add", "i", ["i", "i"])
    t0 = Time.now
    COUNT.times do
      add.call(2, 3)
    end
    t1 = Time.now
    print "#{COUNT} function calls in #{t1 - t0}s"
    assert_equal 5, add.call(2, 3)
  end

end
