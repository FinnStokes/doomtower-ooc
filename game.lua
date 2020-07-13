local building = require("building")
local util = require("util")

local M = {}

local TARGET_HEIGHT = 224

local transform = function(game_x, game_y, screen_width, screen_height)
  local scale = math.floor(screen_height / TARGET_HEIGHT)

  local transform = love.math.newTransform()
  transform:scale(1 / love.graphics.getDPIScale())
  transform:translate(screen_width / 2, screen_height / 2)
  transform:scale(scale, -scale)
  transform:translate(game_x, -game_y)

  return {
    x = game_x,
    y = game_y,
    w = screen_width,
    h = screen_height,
    transform = transform,
  }
end

M.new = function(w, h)
  local state = {
    transform = transform(0, 80, w, h),
    building = building.new(),
    pipe_placer = {},
    placing = false,
    x_speed = 0,
    y_speed = 0,
    cursor = {x = 0, y = 0},
    paused = false,
  }

  return state
end

M.update = function(state, dt)
  local t = state.transform
  if state.y_speed ~= 0 or state.x_speed ~= 0 then
    t = transform(t.x - dt * 100 * state.x_speed, t.y + dt * 100 * state.y_speed, t.w, t.h)
  end
  return util.evolve(state, {
    building = building.update(state.building, dt),
    transform = t,
  })
end

M.press = function(state, action)
  if action == "build_pipe" then
    if state.placing then
      local end_room = state.pipe_placer[#state.pipe_placer]
      if building.is_room(state.building, building.get_tile(state.building, end_room.x, end_room.y)) then
        return util.evolve(state, {
          placing = false,
          building = building.add_pipe(state.building, state.pipe_placer),
          pipe_placer = {},
        })
      else
        return state
      end
    elseif #state.pipe_placer > 1 then
      return util.evolve(state, {placing = true})
    else
      return state
    end
  elseif action == "remove_pipe" then
    if state.placing then
      return util.evolve(state, {placing = false, pipe_placer = {}})
    else
      local self_x, self_y = math.floor(state.cursor.x / building.TILE_SIZE), math.floor(state.cursor.y / building.TILE_SIZE)
      local self = building.get_tile(state.building, self_x, self_y)
      if building.is_pipe(state.building, self) then
        return util.evolve(state, {building = building.remove_pipe(state.building, self)})
      else
        return state
      end
    end
  elseif action == "up" then
    return util.evolve(state, {y_speed = 1})
  elseif action == "down" then
    return util.evolve(state, {y_speed = -1})
  elseif action == "left" then
    return util.evolve(state, {x_speed = -1})
  elseif action == "right" then
    return util.evolve(state, {x_speed = 1})
  else
    return state
  end
end

M.release = function(state, action)
  if action == "up" and state.y_speed == 1 then
    return util.evolve(state, {y_speed = 0})
  elseif action == "down" and state.y_speed == -1 then
    return util.evolve(state, {y_speed = -0})
  elseif action == "left" and state.x_speed == -1 then
    return util.evolve(state, {x_speed = -0})
  elseif action == "right" and state.x_speed == 1 then
    return util.evolve(state, {x_speed = 0})
  else
    return state
  end
end

M.cursor_to = function(state, pos)
  local pipe_placer = state.pipe_placer
  local x, y = state.transform.transform:inverseTransformPoint(pos.x, pos.y)
  local self_x, self_y = math.floor(x / building.TILE_SIZE), math.floor(y / building.TILE_SIZE)
  local other_x, other_y
  if x % building.TILE_SIZE > y % building.TILE_SIZE then
    if building.TILE_SIZE - (x % building.TILE_SIZE) > y % building.TILE_SIZE then 
      other_x, other_y = self_x, self_y - 1
    else
      other_x, other_y = self_x + 1, self_y
    end
  else
    if building.TILE_SIZE - (x % building.TILE_SIZE) > y % building.TILE_SIZE then 
      other_x, other_y = self_x - 1, self_y
    else
      other_x, other_y = self_x, self_y + 1
    end
  end
  local self = building.get_tile(state.building, self_x, self_y)
  local other = building.get_tile(state.building, other_x, other_y)
  if state.placing then
    if not building.is_room(state.building, self) and building.is_room(state.building, other) then
      pipe_placer = building.route_pipe(state.building, pipe_placer[1], pipe_placer[2], {x = self_x, y = self_y}, {x = other_x, y = other_y}) or pipe_placer
    elseif building.is_room(state.building, self) and not building.is_room(state.building, other) then
      pipe_placer = building.route_pipe(state.building, pipe_placer[1], pipe_placer[2], {x = other_x, y = other_y}, {x = self_x, y = self_y}) or pipe_placer
    elseif not building.is_room(state.building, self) then
      pipe_placer = building.route_pipe(state.building, pipe_placer[1], pipe_placer[2], {x = self_x, y = self_y}) or pipe_placer
    end
  else
    if not building.is_room(state.building, self) and building.is_room(state.building, other) then
      pipe_placer = {{x = other_x, y = other_y}, {x = self_x, y = self_y}}
    elseif building.is_room(state.building, self) and not building.is_room(state.building, other) then
      pipe_placer = {{x = self_x, y = self_y}, {x = other_x, y = other_y}}
    else
      pipe_placer = {}
    end
    if not building.pipe_allowed(state.building, pipe_placer) then
      pipe_placer = {}
    end
  end
  return util.evolve(state, {cursor = {x = x, y = y}, pipe_placer = pipe_placer})
end

M.pause = function(state)
  return util.evolve(state, {paused = true})
end

M.resume = function(state)
  return util.evolve(state, {paused = false})
end

M.resize = function(state, w, h)
  return util.evolve(state, {transform = transform(state.transform.x, state.transform.y, w, h)})
end

M.draw = function(state)
  love.graphics.push()
  love.graphics.replaceTransform(state.transform.transform)
  building.render(state.building)
  if #state.pipe_placer > 1 then
    building.render_pipe(state.building, state.pipe_placer, true)
  end
  --love.graphics.circle("fill", 0.0, 80.0, 10.0)
  --love.graphics.circle("line", state.cursor.x, state.cursor.y, 5.0)
  love.graphics.pop()
end

return M
