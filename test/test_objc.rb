# 
# test_objc.rb
# 
# Tests RubyObjC core functions.
#
# Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
# For more information about this file, visit http://www.rubyobjc.com.
#

require 'test/unit'
require 'lib/objc'

class ObjC::NSObject
  use_cmethod("passInt:", "i@:i")
  def self.passInt_(x)
    (x * 1) + 0
  end
end

class TestObjC < Test::Unit::TestCase

  def test_class_method
    #ObjC::Class.find("NSObject").add_class_method_handler("passInt:", "i@:i")
    require 'test/testobject'
    x = ObjC::TestObject.alloc.init
    errors = x.testClassMethod
    assert_equal(0, errors)
  end

  def test_ivars
    require 'test/testobject'
    ivars = ObjC::TestObject.ivars
    assert_equal("_boolValue", ivars[0].name)
    assert_equal("c", ivars[0].type_encoding)
    assert_equal(4, ivars[0].offset)
    ivars = ObjC::NSObject.ivars
    assert_equal(1, ivars.length)
    assert_equal("isa", ivars[0].name)
    assert_equal("#", ivars[0].type_encoding)
    assert_equal(0, ivars[0].offset)
  end

  def test_classes
    classes = ObjC::Class.to_a
    assert(classes.length != 0, "there must be some classes found")
    # classes should be sortable
    classes.sort
    # lookup some classes by name
    nsobject = ObjC::Class.find("NSObject")
    assert(nsobject != nil, "if a class exists, a wrapper must be created")
    nsstring = ObjC::Class.find("NSString")
    assert(nsstring != nil, "if a class exists, a wrapper must be created")
    # lookup a class that doesn't exist
    nothing = ObjC::Class.find("ThisIsNotAClassName")
    assert(nothing == nil, "a wrapper for a nonexistent class must be nil")
    # equality check
    nsobject2 = ObjC::Class.find("NSObject")
    assert(nsobject == nsobject2, "wrappers for the same class must be equal")
    assert(nsobject != nsstring, "wrappers for different classes must not be equal")
    # method access
    class_methods = nsobject.cmethods
    assert(class_methods.length > 0, "a class' methods could not be found")
    instance_methods = nsobject.imethods
    assert(instance_methods.length > 0, "instance methods could not be found")
    # lookup a few instance methods
    instance_methods[0..10].each {|im| assert_not_equal(nil, nsobject.get_imethod(im.to_s))}
    class_methods = nsobject.cmethods
    assert(class_methods.length > 0, "class methods could not be found")
    # lookup a few class methods
    class_methods[0..10].each {|cm| assert_not_equal(nil, nsobject.get_cmethod(cm.name))}
    # class name
    assert_equal("NSObject", nsobject.name)
    assert_equal("NSString", nsstring.name)
    assert_equal("NSObject", nsobject.to_s)
    assert_equal("NSString", nsstring.to_s)
    # superclasses
    assert_equal(nil, nsobject.super)
    assert_equal(nsobject, nsstring.super)
    assert_equal(nsstring, ObjC::Class.find("NSMutableString").super)
    # protocols, noncritical to rubyobjc operation
    assert_equal(["NSObject"], nsobject.protocols)
    assert_equal(["NSCopying", "NSMutableCopying", "NSCoding"], nsstring.protocols)
  end

  def test_methods
    nsmutabledictionary = ObjC::Class.find("NSMutableDictionary")
    assert nsmutabledictionary.imethods.length > 20
    method = nsmutabledictionary.get_imethod "setObject:forKey:"
    assert_equal 4, method.argument_count
    assert_equal "v16@0:4@8@12", method.type_encoding
    assert nsmutabledictionary.cmethods.length > 0
    method = nsmutabledictionary.get_cmethod "dictionaryWithCapacity:"
    assert_equal 3, method.argument_count
    assert_equal "@12@0:4I8", method.type_encoding
  end

  def test_hash
    c = ObjC::Class.find "NSObject"
    d = ObjC::Class.find "NSObject"
    assert_equal true, (c == d)
    assert_equal true, c.eql?(d)
    assert_equal true, (d == c)
    assert_equal true, d.eql?(c)
    assert_equal c.hash, d.hash
    h = {}
    h[c] = 1
    h[d] = 2
    assert_equal 1, h.keys.length
  end

  def test_object_creation
    object1 = ObjC::NSObject.alloc
    object2 = object1.init
    object3 = ObjC::NSString.alloc.init
    assert_not_equal(nil, object1)
    assert_not_equal(nil, object2)
    assert_not_equal(nil, object3)
    view1 = ObjC::NSView.alloc
    view2 = view1.init
    view3 = ObjC::NSView.alloc.init
    assert_not_equal(nil, view1)
    assert_not_equal(nil, view2)
    assert_not_equal(nil, view3)
    assert_raise(NoMethodError) {ObjC::NSView.new}
  end

  def test_message
    hello = "hello, tester"
    s = ObjC::NSString.stringWithString_ hello
    l = s.length
    assert hello.length, l
  end

  def test_array
    a = ObjC::NSMutableArray.alloc.init
    a.addObject_("one")
    a.addObject_(22)
    assert_equal "one", a.objectAtIndex_(0).to_s
    assert_equal 22, a.objectAtIndex_(1).intValue
    assert_equal 22,  a.objectAtIndex_(1).charValue
    assert_equal 2, a.count
    a = nil
  end

  def test_dictionary
    d = ObjC::NSMutableDictionary.alloc.init
    d.setObject_forKey_("one", "two")
    assert_equal "one", d.objectForKey_("two").to_s
    d.setObject_forKey_(13, 22)
    assert_equal 13, d.objectForKey_(22).intValue
    d.setObject_forKey_(1.3, 2.2)
    assert_in_delta 1.3, d.objectForKey_(2.2).floatValue, 1e-6
    assert_equal 1.3, d.objectForKey_(2.2).doubleValue
    d = nil
  end

  def test_conversions
    s = ObjC::NSString.stringWithCString_ "123.45"
    assert_equal 123, s.to_i
    assert_equal 123.45, s.to_f
  end

  def test_properties
    require 'test/testobject'
    x = ObjC::TestObject.alloc.init
    v = true
    x.setBoolValue_ v
    assert_equal 1, x.boolValue
    v = false
    x.setBoolValue_ v
    assert_equal 0, x.boolValue
    v = 123
    x.setIntValue_ v
    assert_equal v, x.intValue
    v = 123456
    x.setLongValue_ v
    assert_equal v, x.longValue
    v = 123.456
    x.setFloatValue_ v
    assert_in_delta v, x.floatValue, 0.00001
    v = 123.456
    x.setDoubleValue_ v
    assert_equal v, x.doubleValue
  end

  def test_signatures
    assert_equal "i@:@", ObjC.get_signature_for_selector("numberOfRowsInTableView:")
    assert_equal "@@:@@i", ObjC.get_signature_for_selector("tableView:objectValueForTableColumn:row:")
    assert_equal "c@:@@i", ObjC.get_signature_for_selector("tableView:shouldEditTableColumn:row:")
    1.times {|i| ObjC.get_signatures} # this mustn't crash
  end

  def test_use
    ObjC::NSObject.use "foo:", "i@:i"
    ObjC::NSObject.use "foo:", "d@:d"
    ObjC::NSObject.use "foo:", "f@:f"
    # we should use the first signature given
    assert_equal "i@:i", ObjC::Class.find("NSObject").get_imethod("foo:").signature
  end

  def test_data
    x = [3,2,1,0,5,4,3].pack("c*")
    assert_equal(7, x.length)
    d = ObjC::NSData.dataWithBytes_length_(x, x.length)
    assert_equal(x, d.to_s)
  end

  def test_ready
    assert_equal(true, ObjC::Ready)
  end
end
