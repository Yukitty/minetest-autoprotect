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

-- Use /protect to get a selection tool.
core.register_chatcommand(autoprotect.command_name, {description="Measure out a plot of land to claim for protection.",
func = function(who)
	local player = core.get_player_by_name(who)
	player:get_inventory():add_item("main", "autoprotect:tool")
	core.chat_send_player(who, "How to use measuring tape:")
	core.chat_send_player(who, "Left click on a node to select corner A.")
	core.chat_send_player(who, "Right click on a node to select corner B.")
	core.chat_send_player(who, "When both corner A and corner B are selected, you will try to claim an area.")
	core.chat_send_player(who, "Press the drop key (Q) to clear the current selection.")
	core.chat_send_player(who, "Drop again to delete the item.")
end})

-- Selection tool.
--[[
	Left click to select corner A.
	Right click to select corner B.
	When both corner A and corner B are selected, tries to claim an area.

	[Q] Drop to deselect both corners.
	Drop with no selection to actually drop the item.
]]
core.register_tool("autoprotect:tool", {
	description = "Measuring Tape (Protection)",
	inventory_image = "autoprotect_tool.png",
	-- set corner 1
	on_place = function(itemstack, player, pointed_thing)
		local pos = pointed_thing.under
		if pos ~= nil then
			autoprotect.select_corner(pos, player:get_player_name(), false)
		end
	end,
	-- set corner 2
	on_use = function(itemstack, player, pointed_thing)
		local pos = pointed_thing.under
		if pos ~= nil then
			autoprotect.select_corner(pos, player:get_player_name(), true)
		end
	end,
	-- drop selection
	on_drop = function(itemstack, player, pos)
		local who = player:get_player_name()
		if autoprotect.selection[who] ~= nil then
			autoprotect.clear_selection(who)
		else
			itemstack:clear()
			return itemstack
			--return core.item_drop(itemstack, player, pos)
		end
	end
})

-- clear selection on join, so nobody gets confused.
core.register_on_joinplayer(function(player)
	local who = player:get_player_name()
	if autoprotect.selection[who] ~= nil then
		autoprotect.clear_selection(who)
	end
end)
