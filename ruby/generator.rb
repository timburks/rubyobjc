# 
# generator.rb
# 
# Code generator to construct Objective-C classes.
# Generates instance variables, accessors, setters, and archiving functions.
# This file is loaded when the <b>generator</b> module is loaded using <b>ObjC.require :generator</b>.
#
# Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
# For more information about this file, visit http://www.rubyobjc.com.
#

require 'erb'
class String # :nodoc:
  def capitalize_first
    self[0..0].upcase + self[1..-1]
  end
end

module ObjC
end

module ObjC::Generator
  @@classes = []
  @@enums = {}

  def self.classes
    @@classes
  end

  def self.find(class_name)
    self.classes.select{|class_info| class_info[0] == class_name}[0]
  end

  class BaseClass
    def self.inherited(klass)
      class_name = klass.name.split("::")[-1]
      superclass_name = klass.superclass.name.split("::")[-1]
      ObjC::Generator.classes << [class_name, superclass_name] unless superclass_name == "BaseClass"
    end

    def self.ivar (varname, vartype)
      class_name = self.name.split("::")[-1]
      ObjC::Generator.find(class_name) << [varname, vartype]
    end
  end

  def self.enum(enum_name, values)
    @@enums[enum_name] = {:enum => enum_name, :values => values}
  end

  def self.enum_typedefs
    result = ""
    template  = ERB.new <<-EOF
typedef enum {<% values.each {|value| %>
  <%= enum_name %><%= value %>,<% } %>
} <%= enum_name %>Type;
EOF
    @@enums.keys.sort_by{|k| k.to_s}.each {|enum_name|
      values = @@enums[enum_name][:values]
      result += template.result(binding)
    }
    result
  end

  def self.class_declarations
    @@classes.map{|class_description| "@class #{class_description[0]};"}.join("\n")
  end

  def self.class_interfaces
    template = ERB.new <<-EOF
//
// <%= class_description[0] %>
//
@interface <%= class_description[0] %> : <%= class_description[1] %>
{<%= ivars class_description %>}
<%= interfaces class_description %>
@end
EOF
    result = ""
    @@classes.each{|class_description|
      result += template.result(binding) + "\n"
    }
    result
  end

  def self.ivars(class_description)
    template = ERB.new <<-EOF
<% class_description[2..-1].each do |pname, ptype| %>
  <%= ptype %> _<%= pname %>;<% end %>
EOF
    template.result(binding)
  end

  def self.interfaces(class_description)
    template = ERB.new <<-EOF
<% class_description[2..-1].each do |pname, ptype| %>
- (<%= ptype %>) <%= pname %>;
- (void) set<%= pname.to_s.capitalize_first %>:(<%= ptype %>) value;<% end %>
EOF
    template.result(binding)
  end

  def self.class_implementations
    template = ERB.new <<-EOF
//
// <%= class_description[0] %>
//
@implementation <%= class_description[0] %>
<%= implementations class_description %>
@end
EOF
    result = ""
    @@classes.each{|class_description|
      result += template.result(binding) + "\n"
    }
    result
  end

  def self.implementations(class_description)
    class_name = class_description[0]
    properties = class_description[2..-1]
    superclass_name = class_description[1]
    template = ERB.new <<-EOF
<% properties.each do |pname, ptype| %>
- (<%= ptype %>) <%= pname %> {return _<%= pname %>;}

- (void) set<%= pname.to_s.capitalize_first %>:(<%= ptype %>) value {<% if ptype[-1..-1] == "*" or ptype == "id" %>
  [value retain];
  [_<%= pname %> release];<% end %>
  _<%= pname %> = value;
}<% end %>

- (void)encodeWithCoder:(NSCoder *)coder
{<% if superclass_name != "NSObject" %>
  [super encodeWithCoder:coder];<% end %><% properties.each do |pname, ptype| %>
  <%= encode_pair(pname, ptype) %><%  end %>
}

- (id) initWithCoder:(NSCoder *)coder
{
  <% if superclass_name != "NSObject" %>[super initWithCoder:coder];<% else %>[super init];<% end %>
  <%  properties.each do |pname, ptype| %>
  <%= decode_pair(pname, ptype) %><%  end %>
  return self;
}
EOF
    template.result(binding)
  end

  def self.encode_pair(pname, ptype)
    case ptype
    when "int":
      return "[coder encodeValueOfObjCType:@encode(int) at:&_#{pname}];"
    when "double":
      return "[coder encodeValueOfObjCType:@encode(double) at:&_#{pname}];"
    when "bool":
      return "[coder encodeValueOfObjCType:@encode(bool) at:&_#{pname}];"
    else
      if ptype.to_s[-1..-1] == "*"
        return "[coder encodeObject:_#{pname}];"
      else
        return "[coder encodeValueOfObjCType:@encode(int) at:&_#{pname}];"
      end
    end
  end


  def self.decode_pair(pname, ptype)
    case ptype
    when "int":
      return "[coder decodeValueOfObjCType:@encode(int) at:&_#{pname}];"
    when "double":
      return "[coder decodeValueOfObjCType:@encode(double) at:&_#{pname}];"
    when "bool":
      return "[coder decodeValueOfObjCType:@encode(bool) at:&_#{pname}];"
    else
      if ptype.to_s[-1..-1] == "*"
        return "_#{pname} = [[coder decodeObject] retain];"
      else
        return "[coder decodeValueOfObjCType:@encode(int) at:&_#{pname}];"
      end
    end
  end

  def self.key_encode_pair(pname, ptype)
    case ptype
    when "int":
      return "[coder encodeInt:_#{pname} forKey:@\"#{pname}\"];"
    when "double":
      return "[coder encodeDouble:_#{pname} forKey:@\"#{pname}\"];"
    when "bool":
      return "[coder encodeBool:_#{pname} forKey:@\"#{pname}\"];"
    else
      if ptype.to_s[-1..-1] == "*"
        return "[coder encodeObject:_#{pname} forKey:@\"#{pname}\"];"
      else
        return "[coder encodeInt:_#{pname} forKey:@\"#{pname}\"];"
      end
    end
  end

  def self.key_decode_pair(pname, ptype)
    case ptype
    when "int":
      return "_#{pname} = [coder decodeIntForKey:@\"#{pname}\"];"
    when "double":
      return "_#{pname} = [coder decodeDoubleForKey:@\"#{pname}\"];"
    when "bool":
      return "_#{pname} = [coder decodeBoolForKey:@\"#{pname}\"];"
    else
      if ptype.to_s[-1..-1] == "*"
        return "_#{pname} = [[coder decodeObjectForKey:@\"#{pname}\"] retain];"
      else
        return "_#{pname} = [coder decodeIntForKey:@\"#{pname}\"];"
      end
    end
  end
end