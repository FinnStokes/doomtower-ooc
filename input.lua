local M = {}

M.default_bindings = {
  mouse = {"build_pipe", "remove_pipe", nil},
  key = {
    escape = "exit",
    f11 = "fullscreen",
  },
}

M.bindings = function()
  local bindings = {mouse = {}, key = {}}

  for k, v in pairs(M.default_bindings.mouse) do
    bindings.mouse[k] = v
  end

  for k, v in pairs(M.default_bindings.key) do
    bindings.key[k] = v
  end

  return bindings
end

M.mouse = function(bindings, button)
  return bindings.mouse[button]
end

M.key = function(bindings, key)
  return bindings.key[key]
end

return M
