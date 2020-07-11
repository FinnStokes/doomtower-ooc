local M = {}

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

return M
