--[[

Minetest module "autoprotect" (script program and related resources)
Copyright © 2014 John J. Muniz (jason.the.echidna@gmail.com)

Released under the terms of WTFPL, see http://www.wtfpl.net/txt/copying/

]]

local falling_node = core.registered_entities["__builtin:falling_node"]
assert(falling_node ~= nil)

do
	local super = falling_node.on_step
	function falling_node:on_step(dtime, ...)
		-- When crossing over into new blocks,
		-- check protection fields for a match.
		local pos = self.object:getpos()
		pos.x, pos.z = math.floor(pos.x), math.floor(pos.z)
		local prev = vector.new(pos.x, math.ceil(pos.y), pos.z)
		pos.y = math.floor(pos.y)
		if pos.y == prev.y or -- haven't crossed over into a new block yet, or
		autoprotect.protection_match(prev, pos) then -- protection fields match.
			return super(self, dtime, ...) -- so just function normally.
		end

		-- Turn into an item and drop at your previous position.
		local drops = core.get_node_drops(self.node.name, "")
		for _,i in pairs(drops) do
			core.add_item(prev, i)
		end
		self.object:remove()
	end
end
