# 
# objc.rb
# 
# This file is automatically loaded when the ObjC module is initialized.
# It contains Ruby code that implements many important features of the ObjC module.
#
# Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
# For more information about this file, visit http://www.rubyobjc.com.
#

# Don't wait for this to be loaded with a framework
ObjC.add_function(ObjC::Function.wrap('NSLog', 'v', ['@']))

class Object # :nodoc:
  class <<self
    alias __original_inherited inherited
    def inherited(child_class)
      child_name = child_class.name
      if /^ObjC::/ =~ child_name && child_name.split(/::/).size == 2
        objc_class_name = child_name.split(/::/)[1]
        objc_class = ObjC::Class.find objc_class_name
        if objc_class
          objc_superclass = objc_class.super
          parent = ObjC::Object.wrapper_for_class(objc_superclass)
          parent = ObjC::Object.wrap_class(objc_superclass) unless parent
          object_class = parent.claim_ruby_subclass(objc_class, objc_class.name)
          ObjC::Object.wrap_methods(objc_class, object_class)
        end
      end
      __original_inherited(child_class)
    end
  end
end

module ObjC
  # Import an Objective-C class for use in Ruby code. In most cases, this is done automatically.
  # A NameError is raised if no corresponding Objective-C class can be found.
  def self.import(*names)
    names.each {|name|
      c = ObjC::Class.find(name.to_s)
      raise NameError, "can't find an Objective-C class named #{name.to_s}" unless c
      ObjC::Object.wrap_class(c)
    }
  end

  # Load all Ruby files in the application directory, with the exception of the specified file (typically main.rb).
  def self.load_internal_files(except_this_file="main.rb")
    path = ObjC::NSBundle.mainBundle.resourcePath.fileSystemRepresentation
    $:.push path
    rbfiles = Dir.entries(path).select {|x| /\.rb\z/ =~ x}
    rbfiles -= [ File.basename(except_this_file) ] if except_this_file
    # use the full path to avoid file name conflicts
    rbfiles.each {|f|
      load(path + "/" + f)
    }
  end

  # Load all Ruby files in same directory as the application.
  def self.load_external_files
    load_all_files external_resource_path
  end

  def self._set_path(path)   # :nodoc:
    if path == :LOCAL and File.exist?(`which ruby`.chomp)
      while $:.shift; end
      File.popen("ruby -e 'puts $:'").readlines.reverse.each {|d| $:.unshift d.chomp}
    elsif path == :INTERNAL
      while $:.shift; end
      $:.unshift internal_resource_path
    elsif path.class == Array
      while $:.shift; end
      path.reverse.each {|d| $:.unshift d.chomp}
    else
      ObjC.NSLog "Unable to set application search path to #{path}"
    end
  end

  # Get a hash containing the method signatures currently known to the Objective-C runtime.
  # This method exhaustively scans the classes and methods in the Objective-C runtime and is surprisingly fast.
  def self.get_signatures
    signatures = {}
    ObjC::Class.each {|c|
      c.cmethods.each {|method|
        signatures[method.name] = method.signature
      }
      c.imethods.each {|method|
        signatures[method.name] = method.signature
      }
    }
    signatures
  end

  # Get a hash containing the methods currently known to the Objective-C runtime.
  # This method exhaustively scans the classes and methods in the Objective-C runtime and is surprisingly fast.
  def self.get_methods
    methods = {}
    ObjC::Class.each {|c|
      c.cmethods.each {|method| methods[method.name] = method}
      c.imethods.each {|method| methods[method.name] = method}
    }
    methods
  end

  # Get the n Objective-C methods that have been most frequently called from Ruby.
  # Returns a list of lists.  Each inner list contains the number of calls, the method,
  # and the method signature.
  # Objective-C method call tracking must be enabled.
  def self.top_methods(n = 10)
    h = self.objc_method_calls
    return nil unless h
    l = []
    h.keys.sort_by{|k| -h[k]}[0..n].each {|k| l << [h[k], k, k.signature]}
    l
  end

  # Get the n Objective-C method signatures that have been most frequently called from Ruby.
  # Returns a list of lists.  Each inner list contains the number of calls and the
  # method signature.
  # Objective-C method call tracking must be enabled.
  def self.top_signatures(n = 10)
    h = self.objc_method_calls
    return nil unless h
    s = Hash.new(0)
    h.each_pair {|k, v|
      s[k.signature] += v
    }
    l = []
    s.keys.sort_by{|k| -s[k]}[0..n].each {|k| l << [s[k], k]}
    l
  end

  # Get the path to an application's internal Resource directory (Cocoa-specific).
  # This method is typically called from a Cocoa application's main.rb file.
  def self.internal_resource_path
    ObjC::NSBundle.mainBundle.resourcePath.fileSystemRepresentation
  end

  # Get the path to the directory that contains the application (Cocoa-specific).
  # This method is typically called from a Cocoa application's main.rb file.
  def self.external_resource_path
    File.dirname(ObjC::NSBundle.mainBundle.bundlePath.fileSystemRepresentation)
  end

  # Load all files in the specified directory (Cocoa-specific).
  # This method is typically called from a Cocoa application's main.rb file.
  def self.load_all_files(path, except_this_file=nil)
    $:.push path
    rbfiles = Dir.entries(path).select {|x| /\.rb\z/ =~ x}
    rbfiles -= [ File.basename(except_this_file) ] if except_this_file
    rbfiles.each do |file|
      result = load( path + "/" + file )
    end
  end

  # INTERNAL: This method is automatically called when an unknown constant is referenced in the ObjC module.
  # If the constant names an Objective-C class, that class is automatically loaded and wrapped,
  # along with any of its superclasses that have not yet been wrapped.
  def self.const_missing(name) # :nodoc:
    objc_class = ObjC::Class.find name.to_s
    if objc_class
      ObjC::Object.wrap_class objc_class
    else
      # try to import a constant...
      raise NameError, "unknown constant #{name}"
    end
  end

  # Get the signature for a given selector from the Objective-C runtime.
  def self.get_signature_for_selector(selector)
    methods = get_methods
    methods[selector].signature
  end

  # Controls the enforcement of imethod/cmethod semantics.
  # When true, the ObjC::Object method_added callback is disabled
  # and methods are not automatically added to the Objective-C runtime.
  # Instead, they must be declared with imethod (for instance
  # methods) or cmethod (for class methods).  When false,
  # method_added attempts to expose all new methods to
  # Objective-C.  The default value is true.
  def self.strict=(strict)
    ObjC::Object.strict= strict
  end
end

class ObjC::Object
  @@methods = nil
  @@enable_method_added_callback = false

  # Declare a class method that is accessible from Objective-C.
  # This is the preferred way to write Ruby methods that are to
  # be added as class methods of Objective-C classes.
  # Method signatures may be optionally specified.
  # For example, the following adds an initialize method
  # to an application delegate class:
  #      class ApplicationDelegate < ObjC::NSObject
  #        cmethod "initialize", "v@:" do
  #            ....
  #        end
  #      end
  # In this case, the "initialize" method is
  # known to the Objective-C runtime and its signature can be
  # safely omitted.
  def self.cmethod(name, signature = nil, &block)
    if signature
      use_cmethod(name, signature)
    else
      use_cmethod(name)
    end
    (class << self; self; end).class_eval do
      self.send(:define_method, name.gsub(":","_"), &block)
    end
  end

  # Declare an instance method that is accessible from Objective-C.
  # This is the preferred way to write Ruby methods that are to
  # be added as instance methods of Objective-C classes.
  # Method signatures may be optionally specified.
  # For example, the following adds a simple instance method
  # to an application delegate class:
  #      class ApplicationDelegate < ObjC::NSObject
  #        imethod "applicationDidFinishLaunching:", "v@:@" do |sender|
  #           ...
  #        end
  #      end
  # In this case, the "applicationDidFinishLaunching:" method is
  # not known to the Objective-C runtime, but because it resembles
  # an action, its signature will be assumed to be "v@:@" and can
  # be safely omitted.
  def self.imethod(name, signature = nil, &block)
    if signature
      use_imethod(name, signature)
    else
      use_imethod(name)
    end
    self.send(:define_method, name.gsub(":","_"), &block)
  end

  # Add a handler for the specified Objective-C method to the ObjC::Object wrapper class.
  # When it is used, this statement must be placed before the corresponding method definition.
  #
  # Direct use of this method is deprecated.  Instead, instance methods should be added by declaring them with imethod.
  # In earlier versions of RubyObjC,
  # Objective-C handlers were automatically added for new Ruby methods whenever a matching signature could be found in the Objective-C runtime
  # or when the method name appears to be an action (of the form "name:", assumed to have signature "v@:@")
  # or accessor (assumed to have signature "@@:").
  def self.use_imethod(methodname, signature=nil) # :nodoc:
    # insert selector into the method table of the Objective-C class
    methodname = methodname.to_s.gsub('_',':')
    if signature == nil
      # lookup signature in cache
      @@methods = ObjC.get_methods if @@methods == nil
      method = @@methods[methodname]
      signature = method.signature if method
    end
    # use a default signature for methods that resemble actions
    signature = "v@:@" if signature == nil and methodname =~ /^[^:]*:$/
    # use a default signature for methods that resemble accessors
    signature = "@@:" if signature == nil and methodname.index(":") == nil
    unless signature
      raise "Unknown signature for method #{methodname}"
    else
      objc_class = self.occlass_for_rbclass[self]
      if objc_class.add_ruby_imethod_handler(methodname,signature)
        ObjC.NSLog "method added: #{self} -- #{methodname} with signature #{signature}" if ObjC.verbose
      end
    end
  end

  # Alias for use_imethod.  Deprecated.
  def self.use(methodname, signature=nil) # :nodoc:
    use_imethod(methodname,signature)
  end

  # Add a class method handler for the specified Objective-C method to the ObjC::Object wrapper class.
  # The corresponding Ruby method must be a class method of the ObjC::Object subclass.
  #
  # Direct use of this method is deprecated.  Instead, class methods should be added by declaring them with cmethod.
  def self.use_cmethod(methodname, signature=nil) # :nodoc:
    if signature == nil
      @@methods = ObjC.get_methods unless @@methods
      method = @@methods[methodname]
      signature = method.signature if method
    end
    # use a default signature for methods that resemble actions
    signature = "v@:@" if signature == nil and methodname =~ /^[^:]*:$/
    # use a default signature for methods that resemble accessors
    signature = "@@:" if signature == nil and methodname.index(":") == nil
    if signature == nil
      raise "Unknown signature for method #{methodname}"
    else
      objc_class = self.occlass_for_rbclass[self]
      if objc_class.add_ruby_cmethod_handler(methodname,signature)
        ObjC.NSLog "method added: #{self} -- #{methodname} with signature #{signature}" if ObjC.verbose
      end
    end
  end

  def self.wrapper_for_class(s) # :nodoc:
    (s == nil) ? ObjC::Object : @@rbclass_for_occlass[s]
  end

  # INTERNAL: This method is used by ObjC.import to create an ObjC::Object subclass
  # that wraps objects of the specified Objective-C class (represented by an instance of ObjC::Class).
  def self.wrap_class(class_wrapper) # :nodoc:
    return @@rbclass_for_occlass[class_wrapper] if @@rbclass_for_occlass[class_wrapper]
    s = class_wrapper.super
    parent = (s == nil) ? ObjC::Object : @@rbclass_for_occlass[s]
    parent = self.wrap_class(s) if not parent
    object_class = parent.add_ruby_subclass(class_wrapper, class_wrapper.name)
    self.wrap_methods(class_wrapper, object_class)
  end

  @@nooverride = ["class", "hash", "new", "self", "superclass", "type"]
  def self.wrap_methods(class_wrapper, object_class) # :nodoc:
    enabling = @@enable_method_added_callback
    @@enable_method_added_callback = false
    class_wrapper.cmethods.sort.each {|method|
      n = method.name.gsub(":","_")
      if @@nooverride.index(n)
        #puts "WARNING: objc can't override class method #{c.name}:#{n}"
        n = "oc_"+n
      end
      #puts "wrapping class method #{n}" if ObjC.verbose
      object_class.add_objc_cmethod_handler(method, n)
    }
    class_wrapper.imethods.sort.each {|method|
      n = method.name.gsub(":","_")
      if @@nooverride.index(n)
        #puts "WARNING: objc can't override instance method #{c.name}:#{n}"
        n = "oc_"+n
      end
      #puts "wrapping instance method #{n}" if ObjC.verbose
      object_class.add_objc_imethod_handler(method, n)
    }
    @@enable_method_added_callback = enabling
    object_class
  end

  # INTERNAL: This method is automatically called when a Ruby class is derived from
  # a Ruby wrapper of objects of an Objective-C class. It uses the ObjC::Class interface
  # to create a new Objective-C class to correspond to the new Ruby class and links
  # the two together in the RubyObjC runtime.  The new Objective-C class is derived
  # from the wrapped Objective-C class.
  def self.inherited(subclass) # :nodoc:
    # puts "inheriting #{subclass} << #{self}"
    # look for the corresponding ObjC class
    subclass_name = subclass.to_s
    subclass_name = subclass_name.split(/::/)[1] if subclass_name.split(/::/).length == 2
    unless ObjC::Class.find subclass_name
      puts "making subclass of #{self} named #{subclass}" if ObjC.verbose
      puts "we need to create an ObjC class named "+subclass_name if ObjC.verbose
      objc_superclass = self.occlass_for_rbclass[self]
      objc_subclass = objc_superclass.add_objc_subclass(subclass_name)
      puts "created #{subclass}" if ObjC.verbose
      ObjC::Object.link_classes(subclass, objc_subclass)
      puts "linked #{subclass}(#{subclass.class}) to #{objc_subclass}(#{objc_subclass.class})" if ObjC.verbose
    end
  end

  def self.strict=(strict) # :nodoc:
    @@enable_method_added_callback = (not strict)
  end

  # INTERNAL: This method is automatically called when a Ruby method is added to
  # a Ruby wrapper of objects of an Objective-C class.  It attempts to add a
  # method to the Objective-C runtime that will allow the Ruby method to be called
  # from Objective-C.  Because this requires type information, it first looks in
  # a hash containing signatures using the method name as the key.  If no signature
  # is found, the method name is examined to see if it resembles a Cocoa action.
  # If so, the signature of an action ("v@:@") is used.  If no signature can obtained,
  # no method handler is added.  To override the default behavior or to add method
  # handlers for methods not known to the Objective-C runtime, see ObjC::Object.use_imethod.
  def self.method_added(id) # :nodoc:
    return unless @@enable_method_added_callback == true
    methodname = id.id2name.to_s.gsub('_',':')
    @@methods = ObjC.get_methods if @@methods == nil
    method = @@methods[methodname]
    signature = method.signature if method
    unless signature
      # use a default signature for methods that resemble actions
      signature = "v@:@" if methodname =~ /^[^:]*:$/
    end
    unless signature
      ObjC.NSLog "method not added: #{self} -- #{methodname}. no signature available." if ObjC.verbose
    else
      objc_class = self.occlass_for_rbclass[self]
      ObjC.NSLog "modifying class #{self} / #{self.superclass}" if ObjC.verbose
      ObjC.NSLog "adding: #{self} -- #{methodname} with signature #{signature}" if ObjC.verbose
      if objc_class.add_ruby_imethod_handler(methodname, signature)
        ObjC.NSLog "method added: #{self} -- #{methodname} with signature #{signature}" if ObjC.verbose
      else
        ObjC.NSLog "method already present: #{self} -- #{methodname}" if ObjC.verbose
      end
    end
  end

  # Declare accessor functions for the specified names that make them available from Objective-C.
  # This will allow these names to be used as outlets in Interface Builder.
  # It also makes them observable using Key Value Observing.
  # Values will be bridged to appropriate subclasses of NSObject.
  def self.objc_accessor(*names)
    self.__add_accessors(names)
  end

  # Synonym for objc_accessor.
  def self.ib_accessor(*names)
    self.__add_accessors(names)
  end

  # Synonym for objc_accessor.
  def self.property(*names)
    self.__add_accessors(names)
  end

  def self.__add_accessors(names) # :nodoc:
    names.each {|name|
      name = name.to_s
      self.class_eval <<-END
      imethod '#{name}', '@@:' do
        @#{name}
      end
      imethod 'set#{name.capitalize_first}:', 'v@:@' do |value|
        willChangeValueForKey_('#{name}')
        @#{name} = value
        didChangeValueForKey_('#{name}')
        nil
      end
      def #{name}=(value)
        willChangeValueForKey_('#{name}')
        @#{name} = value
        didChangeValueForKey_('#{name}')
      end
      END
    }
  end

  # This method is automatically called when an unknown message is sent to an ObjC::Object instance.
  # It attempts to convert the message into an invocation and then tries to forward the invocation to the underlying Objective-C object.
  # If it fails, a NoMethodError exception is raised.
  def method_missing(method, *args)
    begin
      forward(method.to_s.gsub("_", ":"), args)
    rescue NoMethodError
      raise NoMethodError, "undefined method `#{method}` for #{self.class}", caller
    end
  end

  # Get the instance methods defined for the underlying Objective-C class.
  # Returns an array of objects of type ObjC::Method.
  def self.imethods
    @@occlass_for_rbclass[self].imethods
  end

  # Get the class methods defined for the underlying Objective-C class.
  # Returns an array of objects of type ObjC::Method.
  def self.cmethods
    @@occlass_for_rbclass[self].cmethods
  end

  # Get the instance variables defined for the underlying Objective-C class.
  # Returns an array of objects of type ObjC::Variable.
  def self.ivars
    @@occlass_for_rbclass[self].ivars
  end

  # Get the instance variables defined for the underlying Objective-C class.
  # Returns an array of objects of type ObjC::Variable.
  def ivars
    @@occlass_for_rbclass[self.class].ivars
  end

  def all_ivars
    list = ivars
    sc = self.class.superclass
    while sc != ObjC::Object
      list += sc.ivars
      sc = sc.superclass
    end
    list
  end

  # Get the value of a named instance variable, if one exists.
  # The name can be given as a Ruby string or symbol.
  def ivar(name)
    name = name.to_s
    iv = self.all_ivars.select{|item| item.name == name}
    iv ? iv[0]._get(self) : nil
  end

  # Get the superclass of the class of an object.
  def superclass
    self.class.superclass
  end

  private
  def self.rbclass_for_occlass
    @@rbclass_for_occlass
  end

  def self.occlass_for_rbclass
    @@occlass_for_rbclass
  end
end

class ObjC::Class
  # Get a hash representing the hierarchy of all known Objective-C classes.
  def self.hierarchy
    self.to_a.inject({}){|h,c| h[c.name] = c.super ? c.super.name : "nil";h}.inverse
  end
end

# Extensions to Ruby arrays for interoperability with Objective-C.
class Array
  # Convert a Ruby array to an Objective-C NSMutableArray.
  def to_nsarray
    inject(ObjC::NSMutableArray.alloc.init) {|a, item| a << item; a}
  end
end

# Extensions to Ruby hashes for interoperability with Objective-C.
class Hash
  # Convert a Ruby hash to an Objective-C NSMutableDictionary.
  def to_nsdictionary
    d = ObjC::NSMutableDictionary.alloc.init
    each {|key,object| d[key]=object}
    d
  end
  # Invert a Ruby hash.
  def inverse
    i = {}
    each_pair {|k,v| ((v.class == Array) ? v : [v]).each {|x| i[x] = i.has_key?(x) ? [k,i[x]].flatten : k}}
    i
  end
end

# This is the Ruby wrapper for *instance*s of the Objective-C NSObject class.
# It is a child of the ObjC::Object class.
# Like every class descended from ObjC::Object,
# the method table for this class contains entries for the class and instance methods of the corresponding Objective-C class (NSObject).
class ObjC::NSObject
  # Convenience method to set multiple attributes in a single command.
  # Pass attributes in a hash with the attribute names as keys.
  def set(args)
    args.each_pair{|k,v|
      self.send("set#{k.to_s.capitalize_first}_".intern, v)
    }
    self
  end
  # Convenience method for establishing a binding.
  # Pass arguments in a hash with keys :attribute, :object, :keyPath, and :options.
  def bind(args)
    self.bind_toObject_withKeyPath_options_(args[:attribute], args[:object], args[:keyPath], args[:options])
    self
  end
end

# This is the Ruby wrapper for instances of the Objective-C NSArray class.
# It contains a few additional methods to support Ruby-style manipulation
# (it also includes the Ruby Enumerable module).
# These methods are inherited by the Ruby wrappers of all classes derived from NSArray.
# It is a child of ObjC::NSObject, which in turn is a child of the ObjC::Object class.
class ObjC::NSArray
  # Ruby-style indexing into an Objective-C NSArray.
  def [](i)
    i = count + i if (i < 0)
    (i < count) ? objectAtIndex_(i) : nil
  end
  # Ruby-style assignment into an Objective-C NSArray.
  # The array must be of a mutable subclass of NSArray.
  def []=(index,value)
    replaceObjectAtIndex_withObject_(index, object)
  end
  # Ruby-style appending to an Objective-C NSArray.
  # The array must be of a mutable subclass of NSArray.
  def <<(x)
    addObject_(x)
  end
  # Ruby-style enumeration of an Objective-C NSArray.
  def each
    i, max = 0, count
    while i < max
      object = objectAtIndex_(i)
      yield object
      i = i+1
    end
    self
  end
  # Ruby-style size of an Objective-C NSArray.
  def length
    count
  end
  include Enumerable
end

# This is the Ruby wrapper for instances of the Objective-C NSDictionary class.
# It contains a few additional methods to support Ruby-style manipulation.
# These methods are inherited by the Ruby wrappers of all classes derived from NSDictionary.
# It is a child of ObjC::NSObject, which in turn is a child of the ObjC::Object class.
class ObjC::NSDictionary
  # Ruby-style indexing into an Objective-C NSDictionary.
  def [](key)
    objectForKey_(key)
  end
  # Ruby-style setting of objects in an Objective-C NSDictionary.
  # The dictionary must be of a mutable subclass of NSDictionary.
  def []=(key,object)
    setObject_forKey_(object, key)
  end
  # Ruby-style access of keys in an Objective-C NSDictionary.
  def keys
    allKeys
  end
  # Ruby-style access of values in an Objective-C NSDictionary.
  def values
    allValues
  end
  # Convert an Objective-C NSDictionary to a Ruby hash.
  def to_h
    hash = {}
    allKeys.to_a.each {|key| hash[key.to_s] = objectForKey_(key)}
    hash
  end
end

class String # :nodoc:
  def capitalize_first
    self[0..0].upcase + self[1..-1]
  end
end

class RubyObjC < ObjC::NSObject # :nodoc:
  cmethod "loadBundledRuby:", "v@:@" do |bundle|
    ObjC.load_all_files(bundle.resourcePath.fileSystemRepresentation)
  end
end
