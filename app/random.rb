# Aaron Hillegass' RandomApp in 100% Ruby
# to see it the old-fashioned way, see Chapter 2 of Aaron's book:
# "Cocoa Programming for Mac OS X, 2nd Edition"
class RandomAppWindowController < ObjC::NSObject
  attr_accessor :seedButton, :generateButton, :textField, :window

  def init
    super
    styleMask = ObjC::NSTitledWindowMask + ObjC::NSClosableWindowMask + ObjC::NSMiniaturizableWindowMask
    @window = with(ObjC::NSWindow.alloc.initWithContentRect_styleMask_backing_defer_(
    [300,200,340,120], styleMask, ObjC::NSBackingStoreBuffered, false)) do |w|
      w.set(:releasedWhenClosed => 0, :title => 'RandomApp')
      @view = with(ObjC::NSView.alloc.initWithFrame_(w.frame)) do |v|
        @seedButton = with(ObjC::NSButton.alloc.initWithFrame_([20,75,300,25])) do |b|
          b.set({
            :title => "Seed random number generator with time",
            :action => "seed:", :target => self,
            :bezelStyle => ObjC::NSRoundedBezelStyle
          })
          v.addSubview_ b
        end
        @generateButton = with(ObjC::NSButton.alloc.initWithFrame_([20,45,300,25])) do |b|
          b.set({
            :title => "Generate random number",
            :action => "generate:", :target => self,
            :bezelStyle => ObjC::NSRoundedBezelStyle
          })
          v.addSubview_ b
        end
        @textField = with(ObjC::NSTextField.alloc.initWithFrame_([20,20,300,20])) do |t|
          t.set({
            :objectValue => ObjC::NSCalendarDate.calendarDate,
            :editable => false,
            :drawsBackground => false,
            :alignment => ObjC::NSCenterTextAlignment,
            :bezeled => false
          })
          v.addSubview_ t
        end
        w.setContentView_ v
      end
      w.center
      w.makeKeyAndOrderFront_ self
    end
    self
  end

  imethod "seed:" do |sender|
    srand Time.now.to_i
    @textField.setStringValue_ "generator seeded"
  end

  imethod "generate:" do |sender|
    @textField.setIntValue_(rand(100) + 1)
  end
end

def with(x)
  yield x if block_given?; x
end if not defined? with

# create a RandomApp window
def raw
  RandomAppWindowController.alloc.init
end
