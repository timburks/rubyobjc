require 'rexml/document'

module Bridge
  def self.convert(bridgefile)
    result = ""
    doc = REXML::Document.new(File.open(bridgefile).read)
    doc.root.each_element('//enum'){|e|
      name = e.attributes.get_attribute("name").value
      value = eval(e.attributes.get_attribute("value").value)
      result += "ObjC.add_enum('#{name}', #{value})\n"
    }
    doc.root.each_element('//constant'){|e|
      name = e.attributes.get_attribute("name").value
      type = e.attributes.get_attribute("type").value
      if type == '_C_ID'
        result += "ObjC.add_constant('#{name}', '@')\n"
      end
    }
    doc.root.each_element('//class'){|e|
      puts e
    } if false
    doc.root.each_element('//function'){|e|
      puts e
      name = e.attributes.get_attribute("name").value
      returns = e.attributes.get_attribute("returns")
      puts "#{name} #{returns}"
    } if false
    result
  end
end

if __FILE__ == $0
  framework = ARGV[0]
  filename = "/System/Library/Frameworks/#{framework.capitalize}.framework/Versions/C/Resources/BridgeSupport.xml"
  framework_name = framework.capitalize
  case framework
  when "foundation":
    puts <<-END
    ObjC.add_function(ObjC::Function.wrap('NSLog', 'v', ['@']))
    END
  when "appkit":
    framework_name = "AppKit"
    puts <<-END
    ObjC::NSApplication.sharedApplication
    ObjC.add_function(ObjC::Function.wrap('NSApplicationMain', 'i', %w{i ^*}))
    ObjC.add_function(ObjC::Function.wrap('NSBeep', 'v', nil))
    ObjC.add_function(ObjC::Function.wrap('NSRectFill', 'v', %w{{_NSRect={_NSPoint=ff}{_NSSize=ff}}}))
    END
  end
  if File.exist? filename
    puts Bridge.convert(filename)
  else
    filename = "../bridged/#{framework_name}.xml"
    puts Bridge.convert(filename) if File.exist? filename
  end

end
