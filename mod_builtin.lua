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
