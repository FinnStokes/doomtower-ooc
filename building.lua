local util = require("util")
local data = require("data")

local M = {}

M.rooms = {
  {shape = {{0, 0}, {1, 0}, {2, 0}, {3, 0}}},
  {shape = {{0, 0}, {1, 0}, {1, 1}}},
  {shape = {{0, 0}, {0, 1}, {-1, 1}, {1, 1}}},
  {shape = {{0, 0}, {1, 0}, {1, 1}, {0, 1}}},
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
        rooms[id] = {room = room, pos = pos}
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
  local building = {
    rooms = {},
    pipes = {},
    crossings = {},
    grid = grid_add_room({}, entrance, M.rooms[1], {x = 0, y = 0}),
  }

  building.rooms[entrance] = {room=M.rooms[1], pos={x = 0, y = 0}}

  building = M.add_room(building)
  building = M.add_room(building)
  building = M.add_room(building)
  building = M.add_room(building)
  building = M.add_room(building)
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
  elseif x == 0 and y > 0 then
    return "u"
  elseif x == 0 and y < 0 then
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
        love.graphics.draw(img, x, y)
      elseif not M.is_room(building, M.get_tile(building, tiles[i].x, tiles[i].y)) then
        local dir = dir_lbl(tiles[i].x - tiles[i-1].x, tiles[i].y - tiles[i-1].y)
        dirs[dir] = dir
        dir = dir_lbl(tiles[i-1].x - tiles[i].x, tiles[i-1].y - tiles[i].y)
        dirs[dir] = dir
        local img = data.image("pipe-"..dirs.l..dirs.r..dirs.u..dirs.d..suffix)
        love.graphics.draw(img, x, y)
      end
    end
  end
end

M.render = function(building)
  for _, r in pairs(building.rooms) do
    for _, tile in ipairs(r.room.shape) do
      local x = r.pos.x + tile[1]
      local y = r.pos.y + tile[2]
      love.graphics.rectangle("fill", x * M.TILE_SIZE, y * M.TILE_SIZE, M.TILE_SIZE, M.TILE_SIZE)
    end
  end
  for _, p in pairs(building.pipes) do
    M.render_pipe(building, p.shape)
  end
end

return M
