# 
# console.rb
# 
# A Ruby console in a Cocoa text view.
# This file is compiled into the RubyObjC library as an optional component.
# It is loaded when the <b>console</b> module is loaded using <b>ObjC.require :console</b>.
#
# Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
# For more information about this file, visit http://www.rubyobjc.com.
#

require 'irb'

# deprecated
def console(args = {})
  ObjC::Console.display(args)
end

def with(x)
  yield x if block_given?; x
end if not defined? with

module ObjC
  module IB
    def self.scrollView(args)
      with(ObjC::NSScrollView.alloc.initWithFrame_(args[:frame])) {|v|
        v.setAutoresizingMask_(18)
        v.setHasHorizontalScroller_(1)
        v.setHasVerticalScroller_(1)
        v.setBorderType_(2)
        yield v if block_given?
      }
    end
  end
end

module ObjC
  module Console
    @@controller = nil
    @@params = {:exits => true, :title => "Ruby Console", :prompt => "irb", :frame => [30,20,600,300]}

    def self.controller
      @@controller
    end

    def self.params
      @@params
    end

    # run the console
    def self.display(args = {})
      @@params = @@params.merge(args)
      if @@controller
        @@controller.showWindow_(0)
      else
        @@controller = Controller.alloc.initWithArgs(@@params)
        @@controller.run
      end
    end

    class Controller < ObjC::NSWindowController
      attr_accessor :console

      def initWithArgs(args)
        styleMask = ObjC::NSTitledWindowMask + ObjC::NSClosableWindowMask + ObjC::NSMiniaturizableWindowMask + ObjC::NSResizableWindowMask +  ObjC::NSUtilityWindowMask
        initWithWindow_(ObjC::NSPanel.alloc.initWithContentRect_styleMask_backing_defer_(args[:frame], styleMask, ObjC::NSBackingStoreBuffered, false))
        @console = RubyObjCConsole.alloc.initWithArgs(args)
        with window do |w|
          w.setContentView_ IB.scrollView(:frame => args[:frame]) {|sv|
            sv.set(:documentView => @console.textview)
          }
          w.center
          w.set(:title => args[:title], :delegate => self, :opaque => false, :hidesOnDeactivate => false, :frameOrigin => [w.frame[0], 80], :minSize => [600,100])
          w.makeKeyAndOrderFront_(self)
        end
        $consoleController = self
        self
      end

      def run
        @console.performSelector_withObject_afterDelay_("run:", self, 0)
      end

      imethod "windowDidResize:" do |notification|
        @console.moveAndScrollToCursor
      end

      imethod "windowWillClose:" do |notification|
        ObjC::NSApplication.sharedApplication.terminate_(self) if ObjC::Console.params[:exits]
      end

      imethod "windowShouldClose:" do |notification|
        return true unless ObjC::Console.params[:exits]
        @alert = ObjC::NSAlert.alloc.init
        with @alert do |a|
          a.setMessageText_("Do you really want to close this console?\nYour application will exit.")
          a.setAlertStyle_(ObjC::NSCriticalAlertStyle)
          a.addButtonWithTitle_("OK")
          a.addButtonWithTitle_("Cancel")
          a.beginSheetModalForWindow_modalDelegate_didEndSelector_contextInfo_(@window, self, "alertDidEnd:returnCode:contextInfo:", nil)
        end
        false
      end

      imethod "alertDidEnd:returnCode:contextInfo:", "v@:@i^v" do |alert, code, contextInfo|
        window.close if (code == 1000)
      end
    end

    class RubyObjCInputMethod < IRB::StdioInputMethod
      def initialize(console)
        super() # superclass method has no arguments
        @console = console
        @history_index = 1
        @continued_from_line = nil
      end

      def gets
        m = @prompt.match(/(\d+)[>*]/)
        level = m ? m[1].to_i : 0
        if level > 0
          @continued_from_line ||= @line_no
        elsif @continued_from_line
          mergeLastNLines(@line_no - @continued_from_line + 1)
          @continued_from_line = nil
        end
        @console.write @prompt+"  "*level
        string = @console.readLine
        @line_no += 1
        @history_index = @line_no + 1
        @line[@line_no] = string
        string
      end

      def mergeLastNLines(i)
        return unless i > 1
        range = -i..-1
        @line[range] = @line[range].map {|l| l.chomp}.join("\n")
        @line_no -= (i-1)
        @history_index -= (i-1)
      end

      def prevCmd
        return "" if @line_no == 0
        @history_index -= 1 unless @history_index <= 1
        @line[@history_index]
      end

      def nextCmd
        return "" if (@line_no == 0) or (@history_index >= @line_no)
        @history_index += 1
        @line[@history_index]
      end
    end

    # this is an output handler for IRB and a delegate and controller for an NSTextView
    class RubyObjCConsole < ObjC::NSObject
      attr_accessor :textview, :inputMethod

      def initWithArgs(args)
        init
        @textview = ObjC::NSTextView.alloc.initWithFrame_([0,0,args[:frame][2]-17,args[:frame][3]])
        @textview.set(:delegate => self, :richText => false, :continuousSpellCheckingEnabled => false, :autoresizingMask => ObjC::NSViewWidthSizable)
        with(@textview) {|textview|
          textview.set(
          :backgroundColor => ObjC::NSColor.blackColor.colorWithAlphaComponent_(0.8),
          :textColor => ObjC::NSColor.whiteColor,
          :insertionPointColor => ObjC::NSColor.redColor
          )
        } if false
        @inputMethod = RubyObjCInputMethod.new(self)
        @context = Kernel::binding
        @startOfInput = 0
        self
      end

      imethod "run:", "v@:@" do |sender|
        @textview.window.makeKeyAndOrderFront_(self)
        IRB.startInConsole(self)
        ObjC::NSApplication.sharedApplication.terminate_(self)
      end

      def write(object)
        string = object.to_s
        @textview.textStorage.replaceCharactersInRange_withString_([@startOfInput, 0], string)
        @startOfInput += string.length
        @textview.scrollRangeToVisible_([lengthOfTextView, 0])
        handleEvents if ObjC::NSApplication.sharedApplication.isRunning
      end

      def moveAndScrollToIndex(index)
        range = [index, 0]
        @textview.scrollRangeToVisible_(range)
        @textview.setSelectedRange_(range)
      end

      def moveAndScrollToCursor
        moveAndScrollToIndex(@startOfInput)
      end

      def lengthOfTextView
        @textview.textStorage.mutableString.length
      end

      def currentLine
        text = @textview.textStorage.mutableString
        text.substringWithRange_([@startOfInput, text.length - @startOfInput]).to_s
      end

      def readLine
        app = ObjC::NSApplication.sharedApplication
        @startOfInput = lengthOfTextView
        distantFuture = ObjC::NSDate.distantFuture()
        loop do
          event = app.nextEventMatchingMask_untilDate_inMode_dequeue_(ObjC::NSAnyEventMask, distantFuture, ObjC::NSDefaultRunLoopMode, true)
          if (event.oc_type == ObjC::NSKeyDown)
            if event.window
              if (event.window == @textview.window)
                if event.characters.to_s == "\r"
                  break
                end
                if (event.modifierFlags & ObjC::NSControlKeyMask) != 0
                  case event.keyCode
                  when 0:  moveAndScrollToIndex(@startOfInput)     # control-a
                  when 14: moveAndScrollToIndex(lengthOfTextView)  # control-e
                  end
                end
              end
            end
          end
          app.sendEvent_(event)
        end
        lineToReturn = currentLine
        @startOfInput = lengthOfTextView
        moveAndScrollToIndex(@startOfInput)
        write("\n")
        return lineToReturn + "\n"
      end

      def handleEvents
        app = ObjC::NSApplication.sharedApplication
        event = app.nextEventMatchingMask_untilDate_inMode_dequeue_(ObjC::NSAnyEventMask, ObjC::NSDate.dateWithTimeIntervalSinceNow_(1e-6), ObjC::NSDefaultRunLoopMode, true)
        if event
          if (event.oc_type == ObjC::NSKeyDown) and
            event.window and
            (event.window.isEqualTo_ @textview.window) and
            (event.charactersIgnoringModifiers.to_s == 'c') and
            (event.modifierFlags & ObjC::NSControlKeyMask)
            raise IRB::Abort, "abort, then interrupt!!" # that's what IRB says...
          else
            app.sendEvent_(event)
          end
        end
      end

      def replaceLineWithHistory(s)
        range =[@startOfInput, lengthOfTextView - @startOfInput]
        @textview.textStorage.replaceCharactersInRange_withString_(range, s.chomp)
        @textview.scrollRangeToVisible_([lengthOfTextView, 0])
        true
      end

      # delegate methods
      imethod "textView:shouldChangeTextInRange:replacementString:", "c@:@{_NSRange=II}@" do |textview, range, replacement|
        return false if range[0] < @startOfInput
        replacement = replacement.to_s.gsub("\r","\n")
        if replacement.length > 0 and replacement[-1].chr == "\n"
          @textview.textStorage.replaceCharactersInRange_withString_([lengthOfTextView, 0], replacement) if currentLine != ""
          @startOfInput = lengthOfTextView
          false # don't insert replacement text because we've already inserted it
        else
          true  # caller should insert replacement text
        end
      end

      imethod "textView:willChangeSelectionFromCharacterRange:toCharacterRange:", "{_NSRange=II}@:@{_NSRange=II}{_NSRange=II}" do |textview, oldRange, newRange|
        return oldRange if (newRange[1] == 0) and (newRange[0] < @startOfInput)
        newRange
      end

      imethod "textView:doCommandBySelector:", "i@:@:" do |textview, selector|
        case selector
        when "moveUp:"
          replaceLineWithHistory(@inputMethod.prevCmd)
        when "moveDown:"
          replaceLineWithHistory(@inputMethod.nextCmd)
        else
          false
        end
      end
    end
  end
end

module IRB # :nodoc:
  def IRB.startInConsole(console)
    IRB.setup(nil)
    @CONF[:PROMPT_MODE] = :DEFAULT
    @CONF[:PROMPT][:DEFAULT][:PROMPT_I] = "%N:%03n:%i> "
    @CONF[:PROMPT][:DEFAULT][:PROMPT_N] = "%N:%03n:%i> "
    @CONF[:PROMPT][:DEFAULT][:PROMPT_S] = "%N:%03n:%i%l "
    @CONF[:PROMPT][:DEFAULT][:PROMPT_C] = "%N:%03n:%i* "
    @CONF[:VERBOSE] = false
    @CONF[:IRB_NAME] = ObjC::Console.params[:prompt]
    @CONF[:SINGLE_IRB_MODE] = true # avoids a crash; nested irbs don't work
    @CONF[:ECHO] = true
    irb = Irb.new(nil, console.inputMethod)
    # disable irb_rc support out of paranoia
    #@CONF[:IRB_RC].call(irb.context) if @CONF[:IRB_RC]
    @CONF[:MAIN_CONTEXT] = irb.context
    trap("SIGINT") do
      irb.signal_handle
    end
    old_stdout, old_stderr = $stdout, $stderr
    $stdout = $stderr = console
    catch(:IRB_EXIT) do
      loop do
        begin
          irb.eval_input
        rescue Exception
          ObjC.NSLog "Error: #{$!}"
          puts "Error: #{$!}"
        end
        ObjC.NSLog "restarting irb"
      end
    end
    ObjC.NSLog "Leaving console"
    $stdout, $stderr = old_stdout, old_stderr
  end
  class Context # :nodoc:
    def prompting?
      true
    end
  end
end
