local lvfx = require "lvfx"

local banana  = lvfx.newView()
local mango   = lvfx.newView()
local overlay = lvfx.newView()
banana:setClear(0.25, 0.25, 0.25, 1.0)
mango:setClear(0.0, 0.0, 1.0, 0.25)
mango:setCanvas(love.graphics.newCanvas(256, 256))

local mvp = lvfx.newUniform("u_modelViewProjection")
local shader = lvfx.newShader [[
#ifdef VERTEX
uniform mat4 u_modelViewProjection;
vec4 position(mat4 vp, vec4 vertex) {
	return vp * u_modelViewProjection * vertex;
}
#endif
#ifdef PIXEL
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
	vec4 texturecolor = Texel(texture, texture_coords);
	return texturecolor * color;
}
#endif
]]

local function move(x, y)
	mvp:set {
		{ 1, 0, 0, 0 },
		{ 0, 1, 0, 0 },
		{ 0, 0, 1, 0 },
		{ x, y, 0, 1 }
	}
end

local time = 0
function love.update(dt)
	time = time + dt
end

function love.draw()
	move(math.floor(time * 10), 0)
	lvfx.setShader(shader)
	lvfx.setDraw(love.graphics.print, { "Hello!", 200, 20 })
	lvfx.submit(overlay)

	lvfx.setColor(1.0, 0.8, 0.25, 1.0)
	lvfx.setDraw(love.graphics.circle, { "fill", 50, 150, 32 })
	lvfx.submit(banana)

	lvfx.setColor(0.5, 1.0, 0.25, 0.5)
	lvfx.setDraw(love.graphics.circle, { "fill", 50, 50, 32 })
	lvfx.submit(banana, true) -- retain state for next draw

	-- draws another circle of the same color to another view entirely
	lvfx.setDraw(love.graphics.circle, { "fill", 100, 50, 32 })
	lvfx.submit(mango)

	move(0, math.floor(time * 10))
	lvfx.setShader(shader)
	lvfx.setColor(1.0, 0.5, 0.25, 1.0)
	lvfx.setDraw(love.graphics.rectangle, { "fill", 250, 250, 50, 50 })
	lvfx.submit(overlay)

	-- draw another yellow circle to the banana view, still before mango etc
	lvfx.setColor(1.0, 0.8, 0.25, 1.0)
	lvfx.setDraw(love.graphics.circle, { "fill", 50, 150, 32 })
	lvfx.submit(banana)

	lvfx.setDraw(love.graphics.draw, { mango._canvas, 300, 100 })
	lvfx.submit(overlay)

	lvfx.frame {
		banana,
		mango,
		overlay
	}
end
