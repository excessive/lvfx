local lvfx = {}
local lvfx_view = {}
local lvfx_view_mt = {
	__index = lvfx_view
}

local tclear = table.clear or function(t)
	for k, _ in pairs(t) do
		t[k] = nil
	end
end

function lvfx_view:setCanvas(_canvas)
	self._canvas = _canvas or false
end

function lvfx_view:setScissor(_x, _y, _w, _h)
	if not _x then
		self._scissor = false
		return
	end
	self._scissor = {
		x = _x,
		y = _y,
		w = _w,
		h = _h
	}
end

function lvfx_view:setClear(_r, _g, _b, _a)
	local r, g, b, a = _r, _g, _b, _a
	if type(_r) == "table" and #_r >= 3 then
		r, g, b, a = _r[1], _r[2], _r[3], _r[4]
	end
	self._clear = { r, g, b, a or 1.0 }
end

function lvfx.newView()
	local t = {
		_clear   = false,
		_scissor = false,
		_canvas  = false,
		_draws   = {}
	}
	return setmetatable(t, lvfx_view_mt)
end

local lvfx_shader = {}
local lvfx_shader_mt = {
	__index = lvfx_shader
}

function lvfx.newShader(vertex, fragment)
	local t = {
		_handle = love.graphics.newShader(vertex, fragment)
	}
	return setmetatable(t, lvfx_shader_mt)
end

local lvfx_draw = {
	mesh        = false,
	mesh_params = false,
	fn          = false,
	fn_params   = false,
	color       = false,
	shader      = false
}

local lvfx_uniform = {}
local lvfx_uniform_mt = {
	__index = lvfx_uniform
}

-- uniforms updated this frame
local uniforms = {}
function lvfx_uniform:set(...)
	self._data = { ... }
	table.insert(uniforms, self)
	uniforms[self._name] = #uniforms
end

function lvfx.newUniform(name)
	local t = {
		_name = name,
		_data = false
	}
	return setmetatable(t, lvfx_uniform_mt)
end

-- quick shallow copy for submissions
local draw_keys = {}
for k, v in pairs(lvfx_draw) do
	table.insert(draw_keys, k)
end
local function copy_draw(t)
	local clone = {}
	for _, k in ipairs(draw_keys) do
		clone[k] = t[k]
	end
	return clone
end
local state = setmetatable({}, lvfx_draw)

function lvfx.setColor(_r, _g, _b, _a)
	local r, g, b, a = _r, _g, _b, _a
	if type(_r) == "table" and #_r >= 3 then
		r, g, b, a = _r[1], _r[2], _r[3], _r[4]
	end
	state.color = { r, g, b, a or 1.0 }
end

function lvfx.setShader(shader)
	assert(getmetatable(shader) == lvfx_shader_mt)
	state.shader = shader
end

function lvfx.setDraw(mesh, params)
	if type(mesh) == "function" then
		state.fn = mesh
		if params then
			state.fn_params = params
		end
		return
	end

	state.mesh = mesh
	if params then
		state.mesh_params = params
	end
end

function lvfx.submit(view, retain)
	if view then
		assert(getmetatable(view) == lvfx_view_mt)
		local add_state = copy_draw(state)
		add_state.uniforms = {}

		-- this can probably be optimized... with a lot of uniform updates
		-- this could get slow.
		local found = {}
		for i=#uniforms, 1, -1 do
			local uniform = uniforms[i]
			if not add_state.shader then
				break
			end
			if add_state.shader._handle:getExternVariable(uniform._name) then
				-- only record the last update for a given uniform
				if not found[uniform._name] then
					found[uniform._name] = true
					table.insert(add_state.uniforms, {
						_name = uniform._name,
						_data = {unpack(uniform._data)}
					})
				end
			end
		end
		table.insert(view._draws, add_state)
	end
	if not retain then
		state = setmetatable({}, lvfx_draw)
	end
end

local fix_love10_colors = function(t) return t end
if select(2, love.getVersion()) <= 10 then
	fix_love10_colors = function(t)
		return { t[1] * 255, t[2] * 255, t[3] * 255, t[4] * 255 }
	end
end

function lvfx.frame(views)
	for _, view in ipairs(views) do
		assert(getmetatable(view) == lvfx_view_mt)
		love.graphics.setCanvas(view._canvas or nil)
		if view._clear then
			love.graphics.clear(fix_love10_colors(view._clear))
		end
		if view._scissor then
			local rect = view._scissor
			love.graphics.setScissor(rect.x, rect.y, rect.w, rect.h)
		else
			love.graphics.setScissor()
		end
		for _, draw in ipairs(view._draws) do
			love.graphics.push("all")
			if draw.color then
				love.graphics.setColor(fix_love10_colors(draw.color))
			end
			love.graphics.setShader(draw.shader and draw.shader._handle or nil)
			if draw.shader then
				for _, uniform in ipairs(draw.uniforms) do
					local shader = draw.shader._handle
					shader:send(uniform._name, unpack(uniform._data))
				end
			end
			if draw.fn then
				draw.fn(unpack(draw.fn_params or {}))
			elseif draw.mesh then
				love.graphics.draw(draw.mesh, unpack(draw.mesh_params or {}))
			end
			love.graphics.pop()
		end
		tclear(view._draws)
	end

	-- clear hanging submit state, so next frame is clean
	lvfx.submit(false)
	tclear(uniforms)
end

return lvfx
