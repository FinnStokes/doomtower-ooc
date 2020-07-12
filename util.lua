local M = {}

M.clone = function(orig)
  local new = {}
  for k, v in pairs(orig) do
    new[k] = v
  end

  return new
end


M.evolve = function(orig, update)
  local new = {}
  for k, v in pairs(orig) do
    if update[k] ~= nil then
      new[k] = update[k]
    else
      new[k] = v
    end
  end

  return new
end

M.append = function(orig, extra)
  local new = {}
  for k, v in pairs(orig) do
    new[k] = v
  end

  new[#new + 1] = extra

  return new
end

local last_id = 0

M.next_id = function()
  last_id = last_id + 1
  return last_id
end

M.integrated_prob = function(rate, dt)
  local prob = rate * dt
  local rand = math.random()
  return rand < prob
end

M.find = function(table, value)
  for i, val in ipairs(table) do
    if val == value then
      return i
    end
  end
  return 0
end

return M
