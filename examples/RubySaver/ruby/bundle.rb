#
#  RubySaver/bundle.rb
#
# Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.
# For more information about this file, visit http://www.rubyobjc.com.
#
ObjC.set_path :INTERNAL
ObjC.require :foundation, :appkit

class ObjC::RubySaver

  imethod "initWithFrame:isPreview:" do |frame, p|
    super
    @maze = Maze.new(30,50)
    @maze.start_moving
    setAnimationTimeInterval_(0.01)
    self
  end

  imethod "animateOneFrame" do
    @maze.tick if @maze
    setNeedsDisplay_(true)
  end

  imethod "drawRect:" do |rect|
    ObjC::NSColor.blackColor.set
    ObjC.NSRectFill(rect)
    ObjC::NSColor.whiteColor.colorWithAlphaComponent_(0.2).set
    @maze.draw(frame, 20) if @maze
  end

end

class ObjC::NSBezierPath
  def transform(transform)
    self.transformUsingAffineTransform_(transform)
    self
  end
end

class MazeRunner
  attr_accessor :maze, :position, :color, :path, :ticks, :back, :route
  def initialize(maze, position, color=nil)
    @maze = maze
    @position = position
    @color = color ? color : ObjC::NSColor.redColor
    @ticks = 0
    @back = 4
    @old = position.clone
    @path = [@position.clone]
  end

  def actual_position
    x = (0.0 + @position[1] * (@back-@ticks) + @old[1] * @ticks) / @back
    y = (0.0 + @position[0] * (@back-@ticks) + @old[0] * @ticks) / @back
    [y, x]
  end

  def draw
    @color.set
    y, x = actual_position
    ObjC::NSBezierPath.bezierPathWithOvalInRect_([x+0.3, y+0.3, 0.4, 0.4]).transform(@maze.transform).fill
  end

  def draw_path
    @color.colorWithAlphaComponent_(0.5).set
    path = ObjC::NSBezierPath.bezierPath
    p = @path[0]
    path.moveToPoint_ [p[1]+0.5, p[0]+0.5]
    path.setLineWidth_ 2
    @path.each {|p|
      path.lineToPoint_ [p[1]+0.5, p[0]+0.5]
    }
    path.transform @maze.transform
    path.stroke
  end

  def move(direction)
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
    @ticks = @ticks - 1 if @ticks > 0
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

  def initialize(rows, cols, runner=0)
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
    @runners << MazeRunner.new(self, [rows/2, 0], ObjC::NSColor.redColor)
    @runners << MazeRunner.new(self, [rows/2, cols-1], ObjC::NSColor.greenColor)
    @runner = runner
    @allow_moves = true
    @route = nil
    @mazemode = rand 4
    @countdown = 50
    prune
    self
  end

  $historyCount = 20
  $radius = 4
  def compute_transform(frame, margin)

    if true
      current = @runners[@runner].actual_position

      if @allow_moves and @countdown == 0
        width = 2*$radius
        height = 2*$radius
        row = current[0]
        col = current[1]
        row = height/2 if row < height/2
        row = rows - height/2 if row > rows - height/2
        col = width/2 if col < width/2
        col = cols - width/2 if col > cols - width/2
      else
        width = cols
        height = rows
        row = height/2.0
        col = width/2.0
      end


      if @historyRow
        @historyRow[@historyIndex] = row
        @historyCol[@historyIndex] = col
        @historyWidth[@historyIndex] = width
        @historyHeight[@historyIndex] = height
        @historyIndex += 1
        @historyIndex = 0 if @historyIndex == $historyCount
      else 
        @historyRow = [rows/2.0]*$historyCount
        @historyCol = [cols/2.0]*$historyCount
        @historyWidth = [@cols]*$historyCount
        @historyHeight = [@rows]*$historyCount
        @historyIndex = 0
      end
      center = [
        (1.0 / @historyRow.length * @historyRow.inject(0) {|s,i| s + i}),
        (1.0 / @historyCol.length * @historyCol.inject(0) {|s,i| s + i})
      ]
      w0, h0 = frame[2], frame[3]
      w1 = (1.0 / @historyWidth.length * @historyWidth.inject(0) {|s,i| s + i})
      h1 = (1.0 / @historyHeight.length * @historyHeight.inject(0) {|s,i| s + i})
      wscale = (w0 - 2*margin) / w1
      hscale = (h0 - 2*margin) / h1
      scale = (wscale < hscale) ? wscale : hscale
      woffset = (w0 - scale * w1)/2 - center[1] * scale + w1/2 * scale
      hoffset = (h0 - scale * h1)/2 - center[0] * scale + h1/2 * scale
      transform = ObjC::NSAffineTransform.transform
      transform.translateXBy_yBy_(woffset, hoffset)
      transform.scaleXBy_yBy_(scale, scale)
      return transform
    end

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
        initialize(@rows, @cols, 1 - @runner)
        start_moving if @moving
      else
        @restart -= 1
      end
    else
      if @moving
        
        if @countdown > 0
          @countdown -= 1
          return
        end
        
        
        @runners.each {|runner| runner.tick}
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

  def start_moving
    @runners.each {|runner|
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
    @restart = 100
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
      @path.setLineWidth_ 2
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
        break if prune_cell(i,j)
        a = move_across(i,j)
        i,j = a[0],a[1]
      end
      self
    end
  end

  def prune_cell(i,j)
    case @mazemode
    when 0:
      threshold = 1 #uniform
      bias = 2
    when 1:
      bias = 10
      threshold = ((i-@rows/2).abs > (j-@cols/2).abs) ? 1 : bias - 1  # spiral labrynth
    when 2:
      bias = 10
      threshold = ((i-@rows/2)*(j-@cols/2) > 0) ? 1 : bias - 1 # 2x2 checkerboard
    when 3:
      bias = 10
      threshold = (4*j/@cols % 2 == 0) ? 1 : bias - 1 # 4 columns
    end
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
