--[[

Minetest module "autoprotect" (script program and related resources)
Copyright © 2014 John J. Muniz (jason.the.echidna@gmail.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

]]

--[[ Protection fixes for Mesecons ]]--
-- If this file is running, that means 'mesecon' exists.
assert(mesecon ~= nil)
assert(type(mesecon) == "table")

-- Known exploits:
-- Moving stones can push through protection areas.
	-- ✓ Fixed!
-- Moving stones can enter protection areas as an entity and push blocks out of it.
	-- ✓ Fixed!
-- Pistons can push blocks into protection areas.
	-- ✓ Fixed!
-- Sticky pistons can pull blocks out of protection areas.
	-- ✓ Fixed!
-- Pistons can stick their plunger into protection areas if unblocked.
	-- Not fixed!

-- This is for sticky pistons only.
if mesecon.mvps_pull_single then
	local super = mesecon.mvps_pull_single
	mesecon.mvps_pull_single = function(self, pos, dir, ...)
		local pusher_areas, pusher_spawn = autoprotect.get_areas(vector.subtract(pos,dir)) -- remember - pos is the PLUNGER. the actual PUSHER, is one step behind it.
		local areas, spawn = autoprotect.get_areas(vector.add(pos,dir))
		if pusher_spawn ~= spawn then -- spawn protection
			return {}
		end
		for _,a in pairs(areas) do
			local found = false
			for _,b in pairs(pusher_areas) do
				if a.owner == b.owner then
					found = true
					break
				end
			end
			if not found then -- different protection owner
				return {} -- no stack. empty stack. no iterating.
			end
		end
		return super(self, pos, dir, ...)
	end
end

-- Fix mesecons_mvps to not push between protected areas.
if mesecon.mvps_push then
	local super = mesecon.mvps_push
	-- This function doesn't actually require or use self in any way whatsoever,
	-- the authors of mesecons just don't know how to Lua well.
	mesecon.mvps_push = function(self, pos, dir, maximum, ...)
		-- Get the original ownership
		local pusher_areas, pusher_spawn = autoprotect.get_areas(vector.subtract(pos, dir))

		-- Get the areas of every pushed node
		local nodes = mesecon:mvps_get_stack(pos, dir, maximum)
		for _,n in pairs(nodes) do
			local areas, spawn = autoprotect.get_areas(vector.add(n.pos, dir))
			if pusher_spawn ~= spawn then -- spawn protection
				return false -- no pushing
			end
			for _,a in pairs(areas) do
				-- Compare with the pusher's areas
				local found = false
				for _,b in pairs(pusher_areas) do
					if a.owner == b.owner then
						found = true
						break
					end
				end
				-- Tried to enter an area the pusher isn't in.
				if not found then
					return false -- no pushing
				end
			end
		end

		-- Do the push
		return super(self, pos, dir, maximum, ...)
	end
end

-- Fix mesecons_movestones to not move between protected areas.
local mesecon_movestone = core.registered_entities["mesecons_movestones:movestone_entity"]
if mesecon_movestone then
	local super = mesecon_movestone.on_step
	mesecon_movestone.on_step = function(self, dtime, ...)
		local pos = self.object:getpos()
		pos = vector.new(math.floor(pos.x),math.floor(pos.y),math.floor(pos.z))
		local dir = vector.direction(vector.new(0,0,0), self.object:getvelocity())
		local pusher_areas, pusher_spawn = autoprotect.get_areas(pos)
		local areas, spawn = autoprotect.get_areas(vector.add(pos,dir))
		if pusher_spawn ~= spawn then -- spawn protection
			core.add_node(pos, {name="mesecons_movestones:movestone"})
			self.object:remove()
			return
		end
		for _,a in pairs(areas) do
			local found = false
			for _,b in pairs(pusher_areas) do
				if a.owner == b.owner then
					found = true
					break
				end
			end
			if not found then -- we're moving into a new protection area, now stop
				core.add_node(pos, {name="mesecons_movestones:movestone"})
				self.object:remove()
				return
			end
		end
		return super(self, dtime, ...)
	end
end

-- The sticky one too.
local mesecon_movestone = core.registered_entities["mesecons_movestones:sticky_movestone_entity"]
if mesecon_movestone then
	local super = mesecon_movestone.on_step
	mesecon_movestone.on_step = function(self, dtime, ...)
		local pos = self.object:getpos()
		pos = vector.new(math.floor(pos.x),math.floor(pos.y),math.floor(pos.z))
		local dir = vector.direction(vector.new(0,0,0), self.object:getvelocity())
		local pusher_areas, pusher_spawn = autoprotect.get_areas(pos)
		local areas, spawn = autoprotect.get_areas(vector.add(pos,dir))
		if pusher_spawn ~= spawn then -- spawn protection
			core.add_node(pos, {name="mesecons_movestones:movestone"})
			self.object:remove()
			return
		end
		for _,a in pairs(areas) do
			local found = false
			for _,b in pairs(pusher_areas) do
				if a.owner == b.owner then
					found = true
					break
				end
			end
			if not found then -- we're moving into a new protection area, now stop
				core.add_node(pos, {name="mesecons_movestones:sticky_movestone"})
				self.object:remove()
				return
			end
		end
		return super(self, dtime, ...)
	end
end

-- There are actually bugs with how the movestones move and stop normally,
-- causing them to eat blocks and stuff, but it's not my place to fix them.
