local data = require("data")
local util = require("util")

local M = {
  water = {disaster = "out-of-control flooding", img = data.image("water")},
  shark = {disaster = "an out-of-control shark infestation", img = data.image("shark")},
  lightning = {disaster = "out-of-control power fluctiuations", img = data.image("lightning")},
  death = {disaster = "out-of-control corpse hoarding", img = data.image("death")},
  fire = {disaster = "an out-of-control inferno", img = data.image("fire")},
  zombie = {disaster = "an out-of-control zombie horde", img = data.image("zombie")},
  -- radiation = {disaster = "out-of-control micro black holes", img = data.image("radiation")},
  -- robot = {disaster = "an out-of-control robot uprising", img = data.image("robot")},
  -- cold = {disaster = "out-of-control supercooling", img = data.image("cold")},
  steam = {disaster = "out-of-control humidity", img = data.image("steam")},
  laser = {disaster = "out-of-control photonic cascade", img = data.image("laser")},
  laser_shark = {disaster = "out-of-control laser sharks", img = data.image("laser-shark")},
  cyborg = {disaster = "out-of-control cybernetic zombies", img = data.image("cyborg")},
}

M.reactions = {
  -- {consumes = {M.shark}, suppressor = {M.water}, produces = {M.death}},
  {consumes = {M.shark, M.lightning}, catalysts = {M.water}, produces = {M.death}},
  --{consumes = {M.cold}, catalysts = {M.fire}},
  {consumes = {M.death}, catalysts = {M.fire}},
  {consumes = {M.water, M.fire}, produces = {M.steam}},
  {consumes = {M.laser, M.shark}, produces = {M.laser_shark}},
  {consumes = {M.laser, M.zombie}, produces = {M.cyborg}},
  {consumes = {M.laser_shark, M.cyborg}, produces = {M.death, M.death}},
  {consumes = {M.zombie}, catalysts = {M.laser_shark}, produces = {M.death}},
  {consumes = {M.shark}, catalysts = {M.cyborg}, produces = {M.death}},
}

local can_perform = function (elements, action)
  local remaining = util.clone(elements)
  if action.suppressor ~= nil then
    for _, el in ipairs(action.suppressor) do
      local index = util.find(remaining, el)
      if index > 0 then
        return false
      end
    end
  end
  if action.consumes ~= nil then
    for _, el in ipairs(action.consumes) do
      local index = util.find(remaining, el)
      if index > 0 then
        table.remove(remaining, index)
      else
        return false
      end
    end
  end
  if action.catalysts ~= nil then
    for _, el in ipairs(action.catalysts) do
      local index = util.find(remaining, el)
      if index > 0 then
        table.remove(remaining, index)
      else
        return false
      end
    end
  end

  return true
end

local perform = function (elements, action)
  local remaining = util.clone(elements)
  if action.consumes ~= nil then
    for _, el in ipairs(action.consumes) do
      local index = util.find(remaining, el)
      if index > 0 then
        table.remove(remaining, index)
      else
        return nil
      end
    end
  end

  if action.produces ~= nil then
    for _, el in ipairs(action.produces) do
      table.insert(remaining, el)
    end
  end

  return remaining
end

M.act = function(elements, actions)
  for _, action in ipairs(actions) do
    if action.probability == nil or math.random(100) <= action.probability then
      if can_perform(elements, action) then
        local produces = action.produces
        if produces == nil then produces = {} end
        return perform(elements, action), action.produces
      end
    end
  end

  return elements, {}
end

M.react = function(elements)
  local produced = {}
  for _, reaction in ipairs(M.reactions) do
    while can_perform(elements, reaction) do
      elements = perform(elements, reaction)
      if reaction.produces ~= nil then
        for _, el in ipairs(reaction.produces) do
          table.insert(produced, el)
        end
      end
    end
  end

  return elements, produced
end

return M
