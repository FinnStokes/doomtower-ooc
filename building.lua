local data = require("data")
local elements = require("elements")
local util = require("util")

local M = {}

M.rooms = {
  {
    shape = {{0, 0}, {1, 0}, {2, 0}, {3, 0}, {0, 1}, {1, 1}, {2, 1}, {3, 1}, {0, 2}, {3, 2}},
    img = data.image("life"),
    action_rate = 0.5/2,
    actions = {
      {consumes = {elements.death, elements.lightning}, produces = {elements.zombie}},
      {produces = {elements.death}, probability = 20},
    },
  },
  {
    shape = {{0, 0}, {1, 0}, {0, 1}, {1, 1}, {2, 0}, {3, 0}, {4, 0}, {2, 1}, {3, 1}, {4, 1}, {2, 2}, {3, 2}, {4, 2}},
    img = data.image("death-ray"),
    action_rate = 0.2/2,
    actions = {
      {consumes = {elements.shark}, produces = {elements.death}},
      {consumes = {elements.zombie}, produces = {elements.death}},
      {consumes = {elements.laser_shark}, produces = {elements.death}},
      {consumes = {elements.cyborg}, produces = {elements.death}},
      {consumes = {elements.lightning}, produces = {elements.laser}},
      {produces = {elements.fire}, probability = 50},
    },
  },
  {
    shape = {{1, 0}, {1, 1}, {1, 2}, {0, 3}, {1, 3}, {2, 3}, {0, 4}, {1, 4}, {2, 4}},
    img = data.image("weather-control"),
    action_rate = 0.3/2,
    actions = {
      {produces = {elements.lightning}}
    },
  },
  {
    shape = {{0, 0}, {1, 0}, {2, 0}, {0, 1}, {1, 1}, {2, 1}, {0, 2}, {1, 2}, {2, 2}},
    img = data.image("shark-tank"),
    action_rate = 0.2/2,
    actions = {
      {produces = {elements.shark}, probability = 50},
      {produces = {elements.water}},
    },
  },
}

M.TILE_SIZE = 32

M.get_tile = function(building, x, y)
  local row = building.grid[y]
  if row == nil then
    return nil
  end
  return row[x]
end

M.random_tile = function(building)
  local tile = nil
  local x = 0
  local y = 0
  while tile == nil do
    local rows = {}
    for r, row in pairs(building.grid) do
      table.insert(rows, r)
    end
    y = rows[math.random(#rows)]
    local cols = {}
    for c in pairs(building.grid[y]) do
      table.insert(cols, c)
    end
    x = cols[math.random(#cols)]
    tile = M.get_tile(building, x, y)
  end
  return x, y
end

local room_allowed = function(building, room, pos)
  for _, tile in ipairs(room.shape) do
    if M.get_tile(building, pos.x + tile[1], pos.y + tile[2]) ~= nil then
      return false
    end
  end
  return M.get_tile(building, pos.x, pos.y - 1) ~= nil
end

local grid_add = function(grid, id, tiles)
  local new_grid = {}
  local rows = {}
  for y in pairs(grid) do
    rows[y] = true
  end
  for  _, pos in ipairs(tiles) do
    rows[pos.y] = true
  end
  for y in pairs(rows) do
    local local_update = {}
    if grid[y] ~= nil then
      for x, v in pairs(grid[y]) do
        local_update[x] = v
      end
    end
    local has_local_update = false
    for _, pos in ipairs(tiles) do
      if pos.y == y then
        local_update[pos.x] = id
        has_local_update = true
      end
    end
    if has_local_update then
      new_grid[y] = local_update
    else
      new_grid[y] = grid[y]
    end
  end
  return new_grid
end

local grid_add_room = function(grid, id, room, pos)
  local tiles = {}
  for k, v in ipairs(room.shape) do
    tiles[k] = {x = pos.x + v[1], y = pos.y + v[2]}
  end
  return grid_add(grid, id, tiles)
end

M.add_room = function(building)
  local room = M.rooms[math.random(#M.rooms)]
  for i = 1,1000 do
    local x, y = M.random_tile(building)
    while M.get_tile(building, x, y + 1) ~= nil do
      x, y = M.random_tile(building)
    end

    local positions = {}
    for _, v in ipairs(room.shape) do
      table.insert(positions, {x = x - v[1], y = y + 1 - v[2]})
    end

    while #positions > 0 do
      local i = math.random(#positions)
      local pos = positions[i]
      if room_allowed(building, room, pos) then
        local id = util.next_id()
        local rooms = {}
        for id, r in pairs(building.rooms) do
          rooms[id] = r
        end
        rooms[id] = {room = room, pos = pos, elements = {}}
        return util.evolve(building, {
          rooms = rooms,
          grid = grid_add_room(building.grid, id, room, pos),
        })
      end
      table.remove(positions, i)
    end
  end
  return building
end

M.new = function()
  local entrance = util.next_id()
  local entrance_room = M.rooms[math.random(#M.rooms)]

  local building = {
    rooms = {},
    pipes = {},
    crossings = {},
    grid = grid_add_room({}, entrance, entrance_room, {x = 0, y = 0}),
    overflow = false,
    produced = {},
  }

  building.rooms[entrance] = {room=entrance_room, pos={x = 0, y = 0}, elements={}}

  building = M.add_room(building)

  return building
end

M.is_room = function(building, id)
  return building.rooms[id] ~= nil
end

M.is_pipe = function(building, id)
  return building.pipes[id] ~= nil
end

M.is_crossing = function(building, id)
  return building.crossing[id] ~= nil
end

M.pipe_allowed = function(building, shape)
  for i, tile in ipairs(shape) do
    if i > 1 then
      local id = M.get_tile(building, tile.x, tile.y)
      if id ~= nil and (i < #shape or not M.is_room(building, id)) then
        if not M.is_pipe(building, id) then
          return false
        end
        local mydir
        if i < #shape then
          local dxa = shape[i-1].x - shape[i].x
          local dya = shape[i-1].y - shape[i].y
          local dxb = shape[i].x - shape[i+1].x
          local dyb = shape[i].y - shape[i+1].y
          if dxa == dxb and dya == dyb then
            mydir = {x = dxa, y = dya}
          else
            return false
          end
        else
          mydir = {x = shape[i - 1].x - tile.x, y = shape[i - 1].y - tile.y}
        end
        local dir = nil
        local other_shape = building.pipes[id].shape
        for j, _ in ipairs(other_shape) do
          if j > 1 and j < #other_shape then
            if other_shape[j].x == tile.x and other_shape[j].y == tile.y then
              local dxa = other_shape[j-1].x - other_shape[j].x
              local dya = other_shape[j-1].y - other_shape[j].y
              local dxb = other_shape[j].x - other_shape[j+1].x
              local dyb = other_shape[j].y - other_shape[j+1].y
              if dxa == dxb and dya == dyb then
                dir = {x = dxa, y = dya}
              end
            end
          end
        end
        if dir == nil or dir.x * mydir.x + dir.y * mydir.y ~= 0 then
          return false
        end
      end
    end
  end
  return true
end

local key = function(point)
  return point.x .. ',' .. point.y
end

M.route_pipe = function(building, from_room, from, to, to_room)
  local id = M.get_tile(building, to.x, to.y)
  if id ~= nil and not M.is_pipe(building, id) then
    return nil
  end

  local search_space = {{pos=from, path={from_room, from}}}
  local search_idx = 1
  local next_free = 2
  local visited = {}
  visited[key(from_room)] = true
  visited[key(from)] = true

  local visit = function(point, path)
    k = key(point)
    
    if not visited[k] then
      local new_path = util.append(path, point)
      if M.pipe_allowed(building, new_path) then
        visited[k] = true
        search_space[next_free] = {pos = point, path = new_path}
        next_free = next_free + 1
      end
    end
  end

  while search_idx < math.min(next_free, 1000) do
    local current = search_space[search_idx]
    search_space[search_idx] = nil

    if current.pos.x == to.x and current.pos.y == to.y then
      local result = current.path
      if to_room ~= nil then
        if to_room.x == from_room.x and to_room.y == from_room.y and to.x == from.x and to.y == from.y then
          return nil
        end
        result[#result+1] = to_room
      end
      if M.pipe_allowed(building, result) then
        return result
      else
        return nil
      end
    end

    visit({
      x = 2 * current.pos.x - current.path[#current.path - 1].x,
      y = 2 * current.pos.y - current.path[#current.path - 1].y,
    }, current.path)

    visit({
      x = current.pos.x + current.pos.y - current.path[#current.path - 1].y,
      y = current.pos.y - current.pos.x + current.path[#current.path - 1].x,
    }, current.path)

    visit({
      x = current.pos.x - current.pos.y + current.path[#current.path - 1].y,
      y = current.pos.y + current.pos.x - current.path[#current.path - 1].x,
    }, current.path)

    search_idx = search_idx + 1
  end
  return nil
end

local add_pipe = function(building, id, tiles)
  local new_grid = {}
  local rows = {}
  local crossings = nil
  for y in pairs(building.grid) do
    rows[y] = true
  end
  for  _, pos in ipairs(tiles) do
    rows[pos.y] = true
  end
  for y in pairs(rows) do
    local local_update
    if building.grid[y] == nil then
      local_update = {}
    else
      local_update = util.clone(grid[y])
    end
    local has_local_update = false
    for _, pos in ipairs(tiles) do
      if pos.y == y then
        if M.is_pipe(building, local_update[pos.x]) then
          local crossing = util.next_id()
          if crossings == nil then
            crossings = util.clone(building.crossings)
          end
          if math.random(2) == 1 then
            crossings[crossing] = {top = id, bottom = local_update[pos.x]}
          else
            crossings[crossing] = {top = local_update[pos.x], bottom = id}
          end
          local_update[pos.x] = crossing
        else
          local_update[pos.x] = id
        end
        has_local_update = true
      end
    end
    if has_local_update then
      new_grid[y] = local_update
    else
      new_grid[y] = building.grid[y]
    end
  end
  if crossings == nil then
    crosssings = building.crossings
  end
  return util.evolve(building, {crossings = crossings, grid = new_grid})
end


M.add_pipe = function(building, path)
  local id = util.next_id()
  local pipes = {}
  for id, r in pairs(building.pipes) do
    pipes[id] = r
  end
  pipes[id] = {
    shape = path,
    from = M.get_tile(building, path[1].x, path[1].y),
    to = M.get_tile(building, path[#path].x, path[#path].y),
  }
  local short_path = {}
  for k, v in ipairs(path) do
    if k > 1 and k < #path then
      table.insert(short_path, v)
    end
  end
  return util.evolve(building, {
      pipes = pipes,
      grid = grid_add(building.grid, id, short_path),
  })
end

M.remove_pipe = function(building, id)
  local pipes = {}
  for k, r in pairs(building.pipes) do
    if k ~= id then
      pipes[k] = r
    end
  end
  local path = building.pipes[id].shape
  local short_path = {}
  for k, v in ipairs(path) do
    if k > 1 and k < #path then
      table.insert(short_path, v)
    end
  end
  return util.evolve(building, {
      pipes = pipes,
      grid = grid_add(building.grid, nil, short_path),
  })
end

local dir_lbl = function(x, y)
  if x > 0 and y == 0 then
    return "l"
  elseif x < 0 and y == 0 then
    return "r"
  elseif x == 0 and y < 0 then
    return "u"
  elseif x == 0 and y > 0 then
    return "d"
  end
end

M.render_pipe = function(building, tiles, ghost)
  local suffix = ""
  if ghost then suffix = "-ghost" end
  for i, _ in ipairs(tiles) do
    if i > 1 then
      local x = tiles[i].x * M.TILE_SIZE
      local y = tiles[i].y * M.TILE_SIZE
      local dirs = {l = "", r = "", u = "", d = ""}
      if i < #tiles then
        local dir = dir_lbl(tiles[i].x - tiles[i+1].x, tiles[i].y - tiles[i+1].y)
        dirs[dir] = dir
        dir = dir_lbl(tiles[i].x - tiles[i-1].x, tiles[i].y - tiles[i-1].y)
        dirs[dir] = dir
        local img = data.image("pipe-"..dirs.l..dirs.r..dirs.u..dirs.d..suffix)
        love.graphics.draw(img, x, y + M.TILE_SIZE, 0, 1, -1)
      elseif not M.is_room(building, M.get_tile(building, tiles[i].x, tiles[i].y)) then
        local dir = dir_lbl(tiles[i].x - tiles[i-1].x, tiles[i].y - tiles[i-1].y)
        dirs[dir] = dir
        dir = dir_lbl(tiles[i-1].x - tiles[i].x, tiles[i-1].y - tiles[i].y)
        dirs[dir] = dir
        local img = data.image("pipe-"..dirs.l..dirs.r..dirs.u..dirs.d..suffix)
        love.graphics.draw(img, x, y + M.TILE_SIZE, 0, 1, -1)
      end
    end
  end
end

M.render = function(building)
  for _, r in pairs(building.rooms) do
    local left, top = 1000, 0
    for _, tile in ipairs(r.room.shape) do
      local x = r.pos.x + tile[1]
      local y = r.pos.y + tile[2]
      if x < left then left = x end
      if y > top then top = y end
    end
    love.graphics.draw(r.room.img, left * M.TILE_SIZE, (top + 1) * M.TILE_SIZE, 0, 1, -1)
    for n, el in ipairs(r.elements) do
      if n <= #r.room.shape then
        local tile = r.room.shape[n]
        local x = r.pos.x + tile[1]
        local y = r.pos.y + tile[2]
        love.graphics.draw(el.img, x * M.TILE_SIZE, (y + 1) * M.TILE_SIZE, 0, 1, -1)
      end
    end
  end
  for _, p in pairs(building.pipes) do
    M.render_pipe(building, p.shape)
  end
end

local update_pipe = function(pipe, from, to, dt)
  if not util.integrated_prob(1.0, dt) then
    return pipe, from, to
  end

  if #from.elements == 0 then
    return pipe, from, to
  end

  local id = math.random(#from.elements)
  local el = from.elements[id]
  to = util.evolve(to, {
    elements = util.append(to.elements, el),
  })

  local els = {}
  for k, v in ipairs(from.elements) do
    if k ~= id then
      table.insert(els, v)
    end
  end

  from = util.evolve(from, {
    elements = els,
  })

  return pipe, from, to
end

local update_room = function(room, dt)
  local els = room.elements
  if util.integrated_prob(room.room.action_rate, dt) then
    els = elements.act(els, room.room.actions)
  end
  els, produced = elements.react(els)
  local overflow = nil
  if #els > #room.room.shape then
    overflow = {room = room, produced = produced}
  end
  return util.evolve(room, {elements = els}), produced, overflow
end

M.update = function(building, dt)
  local rooms = building.rooms

  local pipes = {}
  for id in pairs(building.pipes) do
    table.insert(pipes, id)
  end

  local updated_rooms = {}
  for id in pairs(building.rooms) do
    updated_rooms[id] = building.rooms[id]
  end

  local updated_pipes = {}
  while #pipes > 0 do
    local n = math.random(#pipes)
    local id = pipes[n]
    local pipe = building.pipes[pipes[n]]
    updated_pipes[pipes[n]], updated_rooms[pipe.from], updated_rooms[pipe.to] = update_pipe(pipe, updated_rooms[pipe.from], updated_rooms[pipe.to], dt)
    table.remove(pipes, n)
  end

  local produced = util.clone(building.produced)
  local overflow = building.overflow

  for id in pairs(building.rooms) do
    local local_produced, local_overflow
    updated_rooms[id], local_produced, local_overflow = update_room(updated_rooms[id], dt)
    if local_overflow ~= nil then
      overflow = local_overflow
    end
    for _, el in ipairs(local_produced) do
      table.insert(produced, el)
    end
  end

  local new = util.evolve(building, {
    produced = produced,
    overflow = overflow,
    rooms = updated_rooms,
    pipes = updated_pipes,
  })

  if util.integrated_prob(0.1, dt) then
      print("New room")
    new = M.add_room(new)
  end

  return new
end

return M
