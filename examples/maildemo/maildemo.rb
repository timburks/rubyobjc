#
#  MailDemo in Ruby
#  maildemo.rb
#
#  Created by Tim Burks on 8/04/06. Revised and ported to RubyObjC on 1/02/07.
#  Copyright (c) 2006 Neon Design Technology, Inc. Some rights reserved.
#  This work is licensed under a Creative Commons Attribution-NonCommercial 2.5 license.
#  Find more information about this file online at http://www.rubyobjc.com/examples
#

def with(x)
  yield x
  x
end

class ObjC::NSTableView
  def [](name)
    tableColumnWithIdentifier_(name)
  end
end

module AutomaticProperties
  def method_missing(m, *args)
    @properties = ObjC::NSMutableDictionary.alloc.init unless @properties
    if m.to_s[-1..-1] == "="
      @properties[m.to_s[0..-2]] = args[0]
    else
      @properties[m.to_s]
    end
  end
end

class Mailbox < ObjC::NSObject
  property :properties, :emails
  include AutomaticProperties

  imethod "init" do
    super
    self.title = "New Mailbox"
    @emails = ObjC::NSMutableArray.alloc.init
    self
  end
end

class Email < ObjC::NSObject
  property :properties
  include AutomaticProperties

  imethod "init" do
    super
    self.address = "test@test.com"
    self.subject = "Subject"
    self.date = ObjC::NSDate.date
    set_body("")
    self
  end

  def set_body(text)
    self.body = ObjC::NSString.stringWithString_(text).dataUsingEncoding_(ObjC::NSUTF8StringEncoding)
  end
end

class MailController < ObjC::NSWindowController
  property :mailboxTable, :emailTable, :previewPane, :emailStatusLine, :mailboxStatusLine
  property :addMailboxButton, :deleteMailboxButton, :addEmailButton, :deleteEmailButton
  property :controllerAlias, :mailboxController, :emailController
  property :mailboxes

  imethod "init" do
    initWithWindowNibName_("MailDemo")
    setup_mailboxes
    w = window # we need this to force the nib to load so that the call to make_bindings will work
    make_bindings
    showWindow_(self)
    self
  end

  # This is optional.  It just loads some arbitrary data
  def setup_mailboxes
    @mailboxes = ObjC::NSMutableArray.alloc.init
    [["One", 3], ["Two", 20], ["Three", 5]].each do |title, count|
      @mailboxes << with(Mailbox.alloc.init) {|mbox|
        mbox.title = title
        count.times {|i| mbox.emails << with(Email.alloc.init) {|email|
          email.address = "sender@address#{i+1}.com"
          email.subject = "subject #{i+1}";
          email.set_body("body of message with subject '#{email.subject}' in mailbox '#{mbox.title}'")
        }}
      }
    end
  end

  def make_bindings
    @controllerAlias = with(ObjC::NSObjectController.alloc.init) {|c|
      c.set(:content => self)
    }
    @mailboxController = with(ObjC::NSArrayController.alloc.init) {|c|
      c.bind(:attribute => :contentArray, :object => @controllerAlias, :keyPath => "selection.mailboxes")
      c.set(:objectClass => Mailbox)
      @addMailboxButton.set(:target => c, :action => "add:")
      @deleteMailboxButton.set(:target => c, :action => "remove:")
      @mailboxTable[:title].bind(:attribute => :value, :object => c, :keyPath => "arrangedObjects.properties.title")
      options = {:NSDisplayPattern => "%{value1}@ Mailboxes"}
      @mailboxStatusLine.bind(:attribute => :displayPatternValue1, :object => c, :keyPath => "arrangedObjects.@count", :options => options)
    }
    @emailController = with(ObjC::NSArrayController.alloc.init) {|c|
      c.bind(:attribute => :contentArray, :object => @mailboxController, :keyPath => "selection.emails")
      c.set(:objectClass => Email)
      @addEmailButton.set(:target => c, :action => "add:")
      @deleteEmailButton.set(:target => c, :action => "remove:")
      with(@emailTable) {|t|
        t[:address].bind(:attribute => :value, :object => c, :keyPath => "arrangedObjects.properties.address")
        t[:subject].bind(:attribute => :value, :object => c, :keyPath => "arrangedObjects.properties.subject")
        t[:date].bind(:attribute => :value, :object => c, :keyPath => "arrangedObjects.properties.date")
      }
      options = {:NSDisplayPattern => "%{value1}@ Emails"}
      @emailStatusLine.bind(:attribute => :displayPatternValue1, :object => c, :keyPath => "arrangedObjects.@count", :options => options)
      @previewPane.bind(:attribute => :data, :object => c, :keyPath => "selection.properties.body")
    }
  end

  imethod "awakeFromNib" do
    @previewPane.setEditable_(false)
  end
end

def maildemo
  MailController.alloc.init
end
