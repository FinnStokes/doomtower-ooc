local M = {}

M.cache = {}

M.image = function(name)
  local filename = 'data/img/'..name..'.png'
  local img = M.cache[filename]
  if img == nil then
    img = love.graphics.newImage(filename)
    img:setFilter('nearest', 'nearest')
    M.cache[filename] = img
  end
  return img
end

return M
