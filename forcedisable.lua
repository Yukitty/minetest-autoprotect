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

-- Post-initialization initialization stuff.
-- To modify the mods we don't even KNOW about!
-- (This is crazy and overzealous and way overstepping our bounds, by the way.)
core.register_on_mapgen_init(function()
	local default_on_punch = core.registered_nodes["default:stone"].on_punch
	for k,v in pairs(core.registered_nodes) do
		-- Override on_punch functions to force protection checking.
		if v.on_punch ~= default_on_punch then
			print("[autoprotect] overriding on_punch for "..k)
			local super = v.on_punch
			v.on_punch = function(pos, node, player, ...)
				local who = player:get_player_name()
				if autoprotect.is_protected(pos, who, false) then
					core.record_protection_violation(pos, who)
					return
				end
				return super(pos, node, player, ...)
			end
		end
		-- Override on_rightclick functions to force protection checking.
		if v.on_rightclick then
			print("[autoprotect] overriding on_rightclick for "..k)
			local super = v.on_rightclick
			v.on_rightclick = function(pos, node, player, ...)
				local who = player:get_player_name()
				if autoprotect.is_protected(pos, who, false) then
					core.record_protection_violation(pos, who)
					return
				end
				return super(pos, node, player, ...)
			end
		end
		-- Add/override inventory metadata management.
		-- Even if the formspec is opened client-side, it shouldn't be manipulable.
		do
			local super = v.allow_metadata_inventory_move
			v.allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player, ...)
				local who = player:get_player_name()
				if autoprotect.is_protected(pos, who, false) then
					core.record_protection_violation(pos, who)
					return 0
				end
				if super then
					return super(pos, from_list, from_index, to_list, to_index, count, player, ...)
				end
			end
		end
		do
			local super = v.allow_metadata_inventory_put
			v.allow_metadata_inventory_put = function(pos, listname, index, stack, player, ...)
				local who = player:get_player_name()
				if autoprotect.is_protected(pos, who, false) then
					core.record_protection_violation(pos, who)
					return 0
				end
				if super then
					return super(pos, listname, index, stack, player, ...)
				end
			end
		end
		do
			local super = v.allow_metadata_inventory_take
			v.allow_metadata_inventory_take = function(pos, listname, index, stack, player, ...)
				local who = player:get_player_name()
				if autoprotect.is_protected(pos, who, false) then
					core.record_protection_violation(pos, who)
					return 0
				end
				if super then
					return super(pos, listname, index, stack, player, ...)
				end
			end
		end
		-- This one is untested. formspecs probably break when they aren't called directly by the client in such a way that they don't end up here at all. @_@
		do
			local super = v.on_receive_fields
			v.on_receive_fields = function(pos, formname, fields, player, ...)
				local who = player:get_player_name()
				if autoprotect.is_protected(pos, who, false) then
					core.record_protection_violation(pos, who)
					return
				end
				if super then
					return super(pos, formname, fields, player, ...)
				end
			end
		end
	end
end)

-- Move formspec to p_formspec so the client doesn't auto-open it.
core.register_on_placenode(function(pos, newnode, placer)
	local areas = autoprotect.get_areas(pos)
	if #areas == 0 then -- no protection
		return -- no need to override formspec just yet
	end
	local meta = core.get_meta(pos)
	local formspec = meta:get_string("formspec")
	if formspec then
		meta:set_string("formspec",nil)
		meta:set_string("p_formspec",formspec)
	end
end)

-- Try to call p_formspec if applicable.
local super_item_place = core.item_place
core.item_place = function(itemstack, player, pointed_thing, ...)
	local pos = pointed_thing.under
	local meta = core.get_meta(pos)
	local formspec = meta:get_string("p_formspec")

	if not formspec or #formspec == 0 then
		return super_item_place(itemstack, player, pointed_thing, ...)
	end

	local who = player:get_player_name()
	if autoprotect.is_protected(pos, who, false) then
		core.record_protection_violation(pos, who)
		return
	end

	formspec = formspec:gsub("current_name", "nodemeta:"..pos.x..","..pos.y..","..pos.z)
	core.show_formspec(who, "nodemeta:"..pos.x..","..pos.y..","..pos.z, formspec)
end
