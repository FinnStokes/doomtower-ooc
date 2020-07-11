game = require("game")
input = require("input")

function love.load()
  math.randomseed(os.time())
  bindings = input.bindings()
  w, h = love.graphics.getPixelDimensions()
  state = game.new(w, h)
end

function love.update(dt)
  state = game.update(state, dt)
end

function press(action)
  if action ~= nil then
    if action == "fullscreen" then
      love.window.setFullscreen(not love.window.getFullscreen())
    elseif action == "exit" then
      love.event.quit(0)
    else
      state = game.press(state, action)
    end
  end
end

function release(action)
  if action ~= nil then
    state = game.release(state, action)
  end
end

function love.keypressed(key)
  press(input.key(bindings, key))
end

function love.keyreleased(key)
  release(input.key(bindings, key))
end

function love.mousepressed(x, y, button, istouch)
  press(input.mouse(bindings, button))
end

function love.mousereleased(x, y, button, istouch)
  release(input.mouse(bindings, button))
end

function love.mousemoved(x, y, istouch)
  x, y = love.window.toPixels(x, y)
  state = game.cursor_to(state, {x = x, y = y})
end

function love.focus(f)
  if not f then
    state = game.pause(state)
  else
    state = game.resume(state)
  end
end

function love.resize(w, h)
  w, h = love.graphics.getPixelDimensions()
  state = game.resize(state, w, h)
end

function love.draw()
  game.draw(state)
end
