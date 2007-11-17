#
#  RubyRocks Revisited
#  RubyRocks.rb
#
# Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
# For more information about this file, visit http://www.rubyobjc.com.
#

NUMBER_OF_ROCKS = 10
MISSILE_SPEED   = 10
MISSILE_LIFE    = 50
TURN_ANGLE      = 0.2
ACCELERATION    = 1
SPEED_LIMIT     = 10

KEY_SPACE       = 49
KEY_LEFT_ARROW  = 123
KEY_RIGHT_ARROW = 124
KEY_DOWN_ARROW  = 125
KEY_UP_ARROW    = 126
KEY_P           = 35
KEY_N           = 45
KEY_R           = 15

class ObjC::NSBezierPath
  imethod "transform:" do |transform|
    self.transformUsingAffineTransform_(transform)
    self
  end
end

class ObjC::NSAffineTransform
  def transformRect(rect)
    origin = transformPoint_([rect[0], rect[1]])
    opposite = transformPoint_([rect[0]+rect[2], rect[1]+rect[3]])
    [origin[0], origin[1], opposite[0] - origin[0], opposite[1] - origin[1]]
  end
end

class RubyRocksView < ObjC::NSView
  imethod "init" do
    initWithFrame_([0,0,100,100])
    @gameRect = [0,0,600,600]
    @game = RubyRocks.alloc.initWithRect(@gameRect)
    @timer = ObjC::NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats_(1.0/60.0, self, "tick:", nil, true)
    setAutoresizingMask_(ObjC::NSViewWidthSizable + ObjC::NSViewHeightSizable)
    @counter = 0
    self
  end

  imethod "dealloc" do
    @timer.invalidate if @timer
  end

  imethod "drawRect:" do |rect|
    ObjC::NSColor.whiteColor.colorWithAlphaComponent_(0.3).set
    ObjC::NSRectFill(rect)
    $transform = compute_transform(rect, @gameRect)
    border = $transform.transformRect(@gameRect)
    ObjC::NSBezierPath.clipRect_ border
    @game.resize if inLiveResize != 0
    @game.draw
    ObjC::NSColor.grayColor.set
    edge = ObjC::NSBezierPath.bezierPathWithRect_(border)
    edge.setLineWidth_ 30.0
    edge.stroke
  end

  imethod "acceptsFirstResponder" do
    true
  end

  imethod "keyDown:" do |event|
    @game.keyDown(event.keyCode)
  end

  imethod "keyUp:" do |event|
    @game.keyUp(event.keyCode)
  end

  imethod "tick:" do |timer|
    @game.tick(timer) if @game
    setNeedsDisplay_(true)
    @counter += 1
    if @counter == 1000
      GC.start
      @counter = 0
    end
  end

  def compute_transform(frame, gameRect)
    xscale = 0.95*frame[2] / gameRect[2]
    yscale = 0.95*frame[3] / gameRect[3]
    scale = (xscale < yscale) ? xscale : yscale
    $scale = scale
    dx = 0.5*(frame[2] - scale * gameRect[2])
    dy = 0.5*(frame[3] - scale * gameRect[3])
    transform = ObjC::NSAffineTransform.transform
    transform.translateXBy_yBy_(dx+frame[0], dy+frame[1])
    transform.scaleXBy_yBy_(scale, scale)
    transform.translateXBy_yBy_(gameRect[0], gameRect[1])
    return transform
  end

  imethod "windowWillClose:" do |sender|
    @timer.invalidate
    @timer = nil
  end
end

# strictly speaking, this class does not need to inherit from NSObject.
# but we do to leave open possible migration to Objective-C
class RubyRocks < ObjC::NSObject
  attr_accessor :bounds

  def initWithRect(b)
    init
    @bounds = b
    @paused = true
    addShip
    addRocks
    @missiles = []
    @sounds = {
      :shipDestroyed => ObjC::NSSound.soundNamed_("Submarine"),
      :rockDestroyed => ObjC::NSSound.soundNamed_("Bottle"),
      :shoot => ObjC::NSSound.soundNamed_("Pop")
    }
    self
  end

  def addShip
    @ship = Ship.alloc.initWithPosition([@bounds[2]/2, @bounds[3]/2])
  end

  def addRocks
    @rocks = []
    NUMBER_OF_ROCKS.times {@rocks << Rock.alloc.initWithPosition([rand(@bounds[2]), rand(@bounds[3])])}
    @rocks.delete_if{|rock| rock.collidesWith?(@ship)}
  end

  def resize
    @topattributes = nil
    @bottomattributes = nil
  end

  def drawTextAtTop(text)
    topCenter    = $transform.transformPoint_([@bounds[2]/2, 0.75*@bounds[3]])
    unless @topattributes
      fontsize = 48.0 * $scale
      @topattributes = ObjC::NSMutableDictionary.dictionary
      @topattributes[ObjC::NSForegroundColorAttributeName] = ObjC::NSColor.whiteColor.colorWithAlphaComponent_(1.0)
      @topattributes[ObjC::NSFontAttributeName] = ObjC::NSFont.boldSystemFontOfSize_(fontsize)
    end
    @string = ObjC::NSString.stringWithString_ text
    size = @string.sizeWithAttributes_(@topattributes)
    @string.drawAtPoint_withAttributes_([topCenter[0]-size[0]/2, topCenter[1]-size[1]/2], @topattributes)
  end

  def drawTextAtBottom(text)
    bottomCenter = $transform.transformPoint_([@bounds[2]/2, 0.25*@bounds[3]])
    unless @bottomattributes
      fontsize = 24.0 * $scale
      @bottomattributes = ObjC::NSMutableDictionary.dictionary
      @bottomattributes[ObjC::NSForegroundColorAttributeName] = ObjC::NSColor.whiteColor.colorWithAlphaComponent_(1.0)
      @bottomattributes[ObjC::NSFontAttributeName] = ObjC::NSFont.boldSystemFontOfSize_(fontsize)
    end
    @string = ObjC::NSString.stringWithString_ text
    size = @string.sizeWithAttributes_(@bottomattributes)
    @string.drawAtPoint_withAttributes_([bottomCenter[0]-size[0]/2, bottomCenter[1]-size[1]/2], @bottomattributes)
  end

  def draw
    ObjC::NSColor.blackColor.colorWithAlphaComponent_(0.95).set
    ObjC::NSRectFill($transform.transformRect(@bounds))
    @rocks.each {|rock| rock.draw}
    @ship.draw if @ship
    @missiles.each {|missile| missile.draw}

    if @paused
      drawTextAtTop "Ruby Rocks"
      drawTextAtBottom "press p to play"
    elsif @ship == nil
      drawTextAtBottom "press n for a new ship"
    elsif @rocks == []
      drawTextAtBottom "press r for more rocks"
    end
  end

  def tick(timer)
    return if @paused
    @rocks.each {|rock| rock.moveWithBounds(@bounds)}
    @ship.moveWithBounds(@bounds) if @ship
    @missiles.each {|missile| missile.moveWithBounds(@bounds)}
    @rocks.each {|rock|
      @missiles.each {|missile|
        if missile.collidesWith?(rock)
          missile.ttl = rock.ttl = 0
          @sounds[:rockDestroyed].play
        end
      }
      if @ship and @ship.collidesWith?(rock)
        @ship.ttl = rock.ttl = 0
        @sounds[:shipDestroyed].play
      end
    }
    @ship = nil if @ship and @ship.ttl == 0
    @rocks.delete_if {|rock| rock.ttl == 0}
    @missiles.delete_if {|missile| missile.ttl == 0}
  end

  def keyDown(code)
    case code
    when KEY_SPACE:
      if @ship
        @missiles << @ship.shoot
        @sounds[:shoot].play
      end
    when KEY_LEFT_ARROW:
      @ship.angle = TURN_ANGLE if @ship
    when KEY_RIGHT_ARROW:
      @ship.angle = -TURN_ANGLE if @ship
    when KEY_UP_ARROW:
      @ship.acceleration = ACCELERATION if @ship
    when KEY_DOWN_ARROW:
      @ship.acceleration = -ACCELERATION if @ship
    when KEY_P:
      @paused = ! @paused
    when KEY_N:
      addShip if not @ship
    when KEY_R:
      addRocks if not @rocks or @rocks.length == 0
    else
      puts "key pressed: #{code}"
    end
  end

  def keyUp(code)
    case code
    when KEY_LEFT_ARROW, KEY_RIGHT_ARROW:
      @ship.angle = 0 if @ship
    when KEY_UP_ARROW, KEY_DOWN_ARROW:
      @ship.acceleration = 0 if @ship
    end
  end
end

# strictly speaking, this class does not need to inherit from NSObject.
# but we do to leave open possible migration to Objective-C
class Sprite < ObjC::NSObject
  attr_accessor :position, :velocity, :radius, :color, :ttl
  def initWithPosition(position)
    init
    @position = position
    @velocity = [0, 0]
    @ttl = -1
    self
  end
  def moveWithBounds(bounds)
    @ttl -= 1 if @ttl > 0
    @position[0] += @velocity[0]
    @position[1] += @velocity[1]
    @position[0] = bounds[2] if @position[0] < 0
    @position[0] = 0 if @position[0] > bounds[2]
    @position[1] = bounds[3] if @position[1] < 0
    @position[1] = 0 if @position[1] > bounds[3]
  end
  def collidesWith?(sprite)
    dx = @position[0] - sprite.position[0]
    dy = @position[1] - sprite.position[1]
    r = @radius + sprite.radius
    return false if dx > r or -dx > r or dy > r or -dy > r
    dx*dx + dy*dy < r*r
  end
end

class Rock < Sprite
  def initWithPosition(position)
    super(position)
    @velocity = [rand-0.5,rand-0.5]
    @color = ObjC::NSColor.whiteColor
    @radius = 30
    self
  end
  def draw
    @color.set
    ObjC::NSBezierPath.bezierPathWithOvalInRect_([@position[0]-@radius, @position[1]-@radius, 2*radius, 2*radius]).transform_($transform).stroke
  end
end

class Ship < Sprite
  attr_accessor :direction, :angle, :acceleration
  def initWithPosition(position)
    super(position)
    @radius = 10
    @color = ObjC::NSColor.redColor
    @direction = [0, 1]
    @angle = @acceleration = 0
    self
  end
  def moveWithBounds(bounds)
    super(bounds)
    if @angle != 0
      cosA = Math::cos(@angle)
      sinA = Math::sin(@angle)
      x = @direction[0] * cosA - @direction[1] * sinA
      y = @direction[1] * cosA + @direction[0] * sinA
      @direction[0], @direction[1] = x, y
    end
    if @acceleration != 0
      speed = Math::sqrt((@velocity[0]+@acceleration*@direction[0])**2 + (@velocity[1]+@acceleration*@direction[1])**2)
      if speed < SPEED_LIMIT
        @velocity[0] += @acceleration * @direction[0]
        @velocity[1] += @acceleration * @direction[1]
      end
    end
  end
  def draw
    @color.set
    x0,y0 = @position[0], @position[1]
    x, y  = @direction[0], @direction[1]
    r = @radius
    path = ObjC::NSBezierPath.bezierPath
    path.moveToPoint_([x0+r*x, y0+r*y])
    path.lineToPoint_([x0+r*(-x +y), y0+r*(-x -y)])
    path.lineToPoint_([x0, y0])
    path.lineToPoint_([x0+r*(-x -y), y0+r*(+x -y)])
    path.transform_($transform).fill
  end
  def shoot
    missilePosition = [position[0]+direction[0], position[1]+direction[1]]
    missileVelocity = [MISSILE_SPEED*direction[0]+velocity[0], MISSILE_SPEED*direction[1]+velocity[1]]
    return Missile.alloc.initWithPositionVelocityAndColor(missilePosition, missileVelocity, @color)
  end
end

class Missile < Sprite
  def initWithPositionVelocityAndColor(position, velocity, color)
    initWithPosition(position)
    @velocity = velocity
    @color = color
    @radius = 3
    @ttl = MISSILE_LIFE
    self
  end
  def draw
    @color.set
    ObjC::NSBezierPath.bezierPathWithOvalInRect_([@position[0]-@radius, @position[1]-@radius, 2*@radius, 2*@radius]).transform_($transform).fill
  end
end

STYLEMASK = ObjC::NSTitledWindowMask + ObjC::NSClosableWindowMask +
ObjC::NSMiniaturizableWindowMask + ObjC::NSResizableWindowMask

class RubyRocksWindowController < ObjC::NSObject
  attr_accessor :window, :view

  def initWithViewAndTitle(v, title)
    init
    ObjC::NSLog STYLEMASK.to_s
    @window = ObjC::NSWindow.alloc.initWithContentRect_styleMask_backing_defer_([30,20,800,800], STYLEMASK, ObjC::NSBackingStoreBuffered, 0)
    @view = v
    @view.set(:autoresizingMask => (ObjC::NSViewWidthSizable + ObjC::NSViewHeightSizable))
    @window.set(:contentView => @view, :opaque => false, :title => title, :delegate => self, :releasedWhenClosed => 0)
    @window.center
    @window.makeKeyAndOrderFront_(self)
    self
  end

  imethod "windowWillClose:" do |sender|
    @view.windowWillClose_(sender)
  end
end

def rubyrocks
  RubyRocksWindowController.alloc.initWithViewAndTitle(RubyRocksView.alloc.init, "ruby rocks")
end
