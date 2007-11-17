#
#  maze.rb
#
# Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
# For more information about this file, visit http://www.rubyobjc.com.
#

KEY_LEFT_ARROW  = 123 if not defined? KEY_LEFT_ARROW
KEY_RIGHT_ARROW = 124 if not defined? KEY_RIGHT_ARROW
KEY_DOWN_ARROW  = 125 if not defined? KEY_DOWN_ARROW
KEY_UP_ARROW    = 126 if not defined? KEY_UP_ARROW
KEY_W = 13 if not defined? KEY_W
KEY_A = 0 if not defined? KEY_A
KEY_S = 1 if not defined? KEY_S
KEY_D = 2 if not defined? KEY_D
KEY_P = 35 if not defined? KEY_P
KEY_O = 31 if not defined? KEY_O
BACK = 5 if not defined? BACK

class ObjC::NSBezierPath
  def transform(transform)
    self.transformUsingAffineTransform_(transform)
    self
  end
end

class MazeView < ObjC::NSView
  attr_accessor :maze, :background

  def initWithMaze(m)
    @background = ObjC::NSColor.yellowColor
    initWithFrame_([0, 0, 100, 100])
    setAutoresizingMask_(ObjC::NSViewWidthSizable + ObjC::NSViewHeightSizable)
    @maze = m
    @timer = ObjC::NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats_(1.0/30.0, self, "tick:", nil, true)
    self
  end

  imethod "windowWillClose:" do |sender|
    @timer.invalidate
    @timer = nil
  end

  imethod "dealloc" do
    @timer.invalidate if @timer
  end

  imethod "tick:" do |timer|
    if @maze
      @maze.tick
      setNeedsDisplay_(true)
    end
  end

  imethod "drawRect:" do |rect|
    @background.set
    ObjC::NSRectFill(rect)
    ObjC::NSColor.blackColor.set
    @maze.draw(frame, 20) if @maze
  end

  imethod "acceptsFirstResponder" do
    true
  end

  imethod "keyDown:" do |event|
    @maze.keyDown(event.keyCode)
  end

  imethod "keyUp:" do |event|
    @maze.keyUp(event.keyCode)
  end
end

class MazeRunner
  attr_accessor :maze, :position, :color, :path, :ticks, :back, :route
  def initialize(maze, position, color=nil)
    @maze = maze
    @position = position
    @color = color ? color : ObjC::NSColor.redColor
    @ticks = 0
    @back = BACK
    @old = position.clone
    @path = [@position.clone]
  end

  def draw
    @color.set
    x = (0.0 + @position[1] * (@back-@ticks) + @old[1] * @ticks) / @back
    y = (0.0 + @position[0] * (@back-@ticks) + @old[0] * @ticks) / @back
    ObjC::NSBezierPath.bezierPathWithOvalInRect_([x+0.1, y+0.1, 0.8, 0.8]).transform(@maze.transform).fill
  end

  def draw_path
    @color.colorWithAlphaComponent_(0.5).set
    path = ObjC::NSBezierPath.bezierPath
    p = @path[0]
    path.moveToPoint_ [p[1]+0.5, p[0]+0.5]
    path.setLineWidth_ 10.0
    @path.each {|p|
      path.lineToPoint_ [p[1]+0.5, p[0]+0.5]
    }
    path.transform @maze.transform
    path.stroke
  end

  def move(direction)
    #return if @ticks > 0
    @old = @position.clone
    @ticks = @back
    if @maze.allow?(@position, direction)
      case direction
      when :left:
        @position[1] -= 1
      when :right:
        @position[1] += 1
      when :up:
        @position[0] += 1
      when :down:
        @position[0] -= 1
      end
      @path << @position.clone
    end
  end

  def tick
    @ticks -= 1 if @ticks > 0
  end
end

class MazeCell
  attr_accessor :topwall, :rightwall, :zone, :score

  def initialize(zone)
    @zone = zone
    @topwall = @rightwall = true
    @score = -1
  end
end

class Maze
  attr_accessor :rows, :cols, :grid, :runners, :transform, :route

  def initialize(rows, cols)
    @rows = rows
    @cols = cols
    @grid = []
    @rows.times {|i|
      row = []
      @cols.times {|j|
        row << MazeCell.new(i*@cols+j)
      }
      @grid << row
    }
    @runners = []
    @runners << MazeRunner.new(self, [rows/2, 0], ObjC::NSColor.purpleColor)
    @runners << MazeRunner.new(self, [rows/2, cols-1], ObjC::NSColor.greenColor)
    @allow_moves = true
    @route = nil
    prune
    self
  end

  def compute_transform(frame, margin)
    w0, h0 = frame[2], frame[3]
    w1, h1 = @cols, @rows
    wscale = (w0 - 2*margin) / w1
    hscale = (h0 - 2*margin) / h1
    scale = (wscale < hscale) ? wscale : hscale
    woffset = (w0 - scale * w1)/2
    hoffset = (h0 - scale * h1)/2
    transform = ObjC::NSAffineTransform.transform
    transform.translateXBy_yBy_(woffset, hoffset)
    transform.scaleXBy_yBy_(scale, scale)
    return transform
  end

  def tick
    if @allow_moves == false
      if @restart == 0
        initialize(10+rand(10),20+rand(20))
        start_moving if @moving
      else
        @restart -= 1
      end
    else
      @runners.each {|runner| runner.tick}
      if @moving
        @runners.each {|runner|
          if runner.ticks == 0
            position = runner.position
            i, j = position[0], position[1]
            nextposition = runner.route[0]
            if nextposition and i == nextposition[0] and j == nextposition[1]
              runner.route = runner.route[1..-1]
              if runner.route.length > 0
                newposition = runner.route[0]
                if newposition[0] == i+1
                  runner.move(:up)
                elsif newposition[0] == i-1
                  runner.move(:down)
                elsif newposition[1] == j-1
                  runner.move(:left)
                elsif newposition[1] == j+1
                  runner.move(:right)
                end
                if collision?
                  game_over
                end
              end
            end
          end
        }
      end
    end
  end

  def keyDown(code)
    return if not @allow_moves
    case code
      #when 86: @runners[0].move(:left) if @runners[0]
      #when 88: @runners[0].move(:right) if @runners[0]
      #when 91: @runners[0].move(:up) if @runners[0]
      #when 84: @runners[0].move(:down) if @runners[0]
      #when 2: @runners[1].move(:left) if @runners[1]
      #when 5: @runners[1].move(:right) if @runners[1]
      #when 15: @runners[1].move(:up) if @runners[1]
      #when 3: @runners[1].move(:down) if @runners[1]
    when KEY_LEFT_ARROW:      @runners[1].move(:left) if @runners[1]
    when KEY_RIGHT_ARROW:      @runners[1].move(:right) if @runners[1]
    when KEY_UP_ARROW:      @runners[1].move(:up) if @runners[1]
    when KEY_DOWN_ARROW:      @runners[1].move(:down) if @runners[1]
    when KEY_A:      @runners[0].move(:left) if @runners[0]
    when KEY_D:      @runners[0].move(:right) if @runners[0]
    when KEY_W:      @runners[0].move(:up) if @runners[0]
    when KEY_S:      @runners[0].move(:down) if @runners[0]
    when KEY_P: connect
    when KEY_O: start_moving #animate
    else
      puts "key pressed in maze: #{code}" if @blab
    end

    if collision?
      game_over
    end
  end

  def keyUp(code)
    puts "key released in maze: #{code}" if @blab
  end

  def start_moving
    @runners.each {|runner|
      runner.back = 3
      start = runner.position
      finish = @runners.select{|r| r != runner}[0].position
      unmark
      mark_and_propagate(finish, start, 0)
      runner.route = trace_back(start.clone)
    }
    @moving = true
  end
  def collision?
    @runners[0].position[0] == @runners[1].position[0] and @runners[0].position[1] == @runners[1].position[1]
  end

  def game_over
    @allow_moves = false
    @restart = 75
  end

  def allow?(position, direction)
    return false if direction == :left and position[1] == 0
    return false if direction == :right and position[1] == @cols-1
    return false if direction == :up and position[0] == @rows-1
    return false if direction == :down and position[0] == 0
    i, j = position[0], position[1]
    return false if direction == :up and @grid[i][j].topwall
    return false if direction == :right and @grid[i][j].rightwall
    return false if direction == :down and @grid[i-1][j].topwall
    return false if direction == :left and @grid[i][j-1].rightwall
    true
  end

  def draw(frame, margin)
    @transform = compute_transform(frame, margin)
    if not @path
      @path = ObjC::NSBezierPath.bezierPath

      @path.setLineWidth_ 1

      #@path.setLineCapStyle ObjC::NSRoundLineCapStyle
      #@dashcount = 2
      #@dasharray = [4,3].pack('f2')
      #@path.setLineDash_count_phase(@dasharray, @dashcount, 0)
      @rows.times {|i|
        @cols.times {|j|
          cell = @grid[i][j]
          if cell.topwall
            @path.moveToPoint_ [j, i+1]
            @path.lineToPoint_ [j+1, i+1]
          end
          if cell.rightwall
            @path.moveToPoint_ [j+1, i+1]
            @path.lineToPoint_ [j+1, i]
          end
          if i == 0
            @path.moveToPoint_ [j, i]
            @path.lineToPoint_ [j+1, i]
          end
          if j == 0
            @path.moveToPoint_ [j, i+1]
            @path.lineToPoint_ [j, i]
          end
        }
      }
    end

    p = @path.copy.transform(@transform).stroke
    if @allow_moves
      @runners.each {|runner| runner.draw}
    else
      @runners.each {|runner| runner.draw_path}
    end

    if @route
      ObjC::NSColor.blueColor.colorWithAlphaComponent_(0.5).set
      path = ObjC::NSBezierPath.bezierPath
      p = @route[0]
      path.moveToPoint_ [p[1]+0.5, p[0]+0.5]
      path.setLineWidth_ 5.0
      @route.each {|p|
        path.lineToPoint_ [p[1]+0.5, p[0]+0.5]
      }
      path.transform @transform
      path.stroke
    end

  end

  def reachable_neighbors(position)
    i, j = position[0], position[1]
    n = []
    n << [i, j-1] if j > 0 and not @grid[i][j-1].rightwall
    n << [i-1, j] if i > 0 and not @grid[i-1][j].topwall
    n << [i, j+1] if j+1 < @cols and not @grid[i][j].rightwall
    n << [i+1, j] if i+1 < @rows and not @grid[i][j].topwall
    n
  end

  def relabel(oldzone, newzone, position)
    i, j = position[0], position[1]
    cell = @grid[i][j]
    if cell.zone == oldzone
      cell.zone = newzone
      reachable_neighbors(position).each {|neighbor| relabel(oldzone, newzone, neighbor)}
    end
  end

  def mark_and_propagate(position, goal, score, continuing=false)
    $finished_marking = false if not continuing
    i, j = position[0], position[1]
    cell = @grid[i][j]
    if cell.score == -1
      cell.score = score
      $finished_marking = true if i == goal[0] and j == goal[1]
      reachable_neighbors(position).each {|neighbor| mark_and_propagate(neighbor, goal, score+1, true)}
    end
  end

  def trace_back(position)
    i, j = position[0], position[1]
    score = @grid[i][j].score
    return [position] if score == 0
    reachable_neighbors(position).each {|neighbor|
      return [position].concat(trace_back(neighbor)) if @grid[neighbor[0]][neighbor[1]].score == score-1
    }
    return []
  end

  def unmark
    @grid.each {|row| row.each {|cell| cell.score = -1}}
  end

  def connect
    unmark
    start = @runners[0].position
    finish = @runners[1].position
    mark_and_propagate(finish, start, 0)
    @route = trace_back(start.clone)
    @route.length
  end

  def hop
    @runners[0].position = [rand(@rows), rand(@cols)]
    @runners[1].position = [rand(@rows), rand(@cols)]
    connect
  end

  def animate(n = 100)
    n.times {
      hop
      $console.console.handleEvents
    }
  end

  def move_across(i,j)
    if i < @rows-1
      i += 1
    else
      i = 0
      if j < @cols-1
        j += 1
      else
        j = 0
      end
    end
    [i, j]
  end

  def prune
    @count = 0
    @path = nil
    (@rows*@cols+10).times do
      i,j = rand(@rows), rand(@cols)
      (@rows*@cols).times do
        @count += 1
        #        ConsoleWindowController.instance.console.handleEvents if (@count % 1000) == 0
        break if prune_cell(i,j)
        a = move_across(i,j)
        i,j = a[0],a[1]
      end
      self
    end
  end

  def prune_cell(i,j)
    bias = 2
    threshold = 1
    #threshold = ((i-@rows/2).abs > (j-@cols/2).abs) ? 1 : bias - 1
    #threshold = ((i-@rows/2)*(j-@cols/2) > 0) ? 1 : bias - 1
    #threshold = (4*j/@cols % 2 == 0) ? 1 : bias - 1
    #threshold = 1
    if rand(bias) < threshold
      if i < @rows - 1
        cell1 = @grid[i][j]
        cell2 = @grid[i+1][j]
        if cell1.zone != cell2.zone
          cell1.topwall = false
          if cell1.zone < cell2.zone
            relabel(cell2.zone, cell1.zone, [i+1, j])
          else
            relabel(cell1.zone, cell2.zone, [i, j])
          end
          return true
        end
      end
    else
      if j < @cols - 1
        cell1 = @grid[i][j]
        cell2 = @grid[i][j+1]
        if cell1.zone != cell2.zone
          cell1.rightwall = false
          if cell1.zone < cell2.zone
            relabel(cell2.zone, cell1.zone, [i, j+1])
          else
            relabel(cell1.zone, cell2.zone, [i, j])
          end
          return true
        end
      end
    end
    false
  end
end

class MazeWindowController < ObjC::NSWindowController
  attr_accessor :window, :view
  def initWithView_title_(v, title)
    init
    @window = ObjC::NSWindow.alloc.initWithContentRect_styleMask_backing_defer_([30,20,800,600], 15, ObjC::NSBackingStoreBuffered, 0)
    @window.setReleasedWhenClosed_ 0
    @view = v
    @view.setAutoresizingMask_(ObjC::NSViewWidthSizable + ObjC::NSViewHeightSizable)
    @window.setContentView_ @view
    @window.setOpaque_ false
    @window.setTitle_ title
    @window.setDelegate_ self
    @window.center
    @window.makeKeyAndOrderFront_(self)
    self
  end

  imethod "windowWillClose:" do |sender|
    @view.windowWillClose_(sender)
  end
end

def maze(r=20,c=20)
  m = MazeView.alloc.initWithMaze(Maze.new(r,c))
  MazeWindowController.alloc.initWithView_title_(m, "maze")
end
