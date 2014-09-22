--[[

Minetest module "autoprotect" (script program and related resources)
Copyright © 2014 John J. Muniz (jason.the.echidna@gmail.com)

Released under the terms of WTFPL, see http://www.wtfpl.net/txt/copying/

]]

autoprotect = {}

--[[ Settings ]]--

-- File name of the world-specific database to store protection ranges and owners in.
autoprotect.db_filename = "protection.txt"

-- Spawn protection range (set to 0 or nil to disable)
autoprotect.spawn_protection = 15

-- Protection limits
autoprotect.initial_blocks = 10*10 -- Maximum horizontal range to protect for new users
autoprotect.vertical_range = {-150,150} -- Vertical range to protect by default (relative to the assumed center of the protected area, not from 0)

-- Command to obtain a protection tool.
autoprotect.command_name = "protect"

-- Announce who owns the area you're building in, if it's different from the last block you placed/broke.
autoprotect.announce_area = true

-- Unlocked storage blocks which users should be warned about placing outside of protection.
autoprotect.chests = {"default:chest"}

-- Automatically claim first area when a user places a block from autoprotect.chests with no protection around it.
autoprotect.firstclaim = true
autoprotect.firstradius = 5 -- radius to claim, should not be more than half of the square root of initial_blocks

--[[ End of Settings ]]--

--[[ API ]]--

-- Return all relevant protection areas which overlap a position.
function autoprotect.get_areas(pos) end

-- Returns _true_ if any of this mod's protection areas blocks 'who' from manipulating the block at 'pos', _false_ otherwise.
-- Will also tell 'who' where they are building if 'announce' is _true_.
function autoprotect.is_protected(pos, who, announce) end

-- Protection checking for non-users
-- Returns _true_ if the protection areas of 'new_pos' are equal to or more permissive than the protection areas of 'pos'
-- Returns _false_ if the 'new_pos' crosses into new protection areas that 'pos' does not have.
function autoprotect.protection_match(pos, new_pos) end

-- Adds a corner to autoprotect.selection[who][which]
function autoprotect.select_corner(pos, who, which) end

-- Clears a the player's selection (sets autoprotect.selection[who] to nil)
function autoprotect.clear_selection(who) end

-- Claim an area from vector 'a' to vector 'b' for 'who's protection.
function autoprotect.claim(who, a, b) end

-- Save protection data to world file.
-- 'filename' can override destination.
function autoprotect.save_protection(filename) end

-- Load protection data from world file.
-- 'filename' can override source.
function autoprotect.read_protection(filename) end

-- List of all protected areas
autoprotect.protection = {
	{min_x,min_y,min_z, max_x,max_y,max_z, owner="owner name", allowed={"list","of","guests"}}
}

-- Current block usage by user
-- Corresponds to horizontal space in all protected areas.
autoprotect.blocks = {
	["host"] = 25
}

-- Protection limits (by user)
-- May be increased/decreased dynamically.
--
-- autoprotect.initial_blocks is added to this, so it starts at 0 and CAN actually be negative.
--
-- This is so that server hosts can change their mind and decide to start players off with
-- less claim and it will retroactively affect everyone.
autoprotect.limits = {
	["host"] = 0
}

-- Last recorded and announced building area, for warning messages.
autoprotect.area = {
	["host"] = false
	--[[ Possible options:
		false : unclaimed territory
		true : spawn protection
		"owner name" : owner name's protected area
	]]
}

-- Current protection selections
-- (For defining new areas and visualizing existing ones.)
autoprotect.selection = {
	["host"] = { -- user name
		{x=5,y=0,z=-5}, -- user input selection corner A
		{x=-5,y=2,z=5}, -- user input selection corner B
		{x=-5,y=-149,z=-5}, -- calculated selection minp (including vertical_range)
		{x=5,y=151,z=5} -- calculated selection maxp (including vertical_range)
	}
}

--[[
Privileges:

'spawnprotection'
	Immune to spawn protection even if it's not disabled. Anyone with this priv can build in the spawn area.

'inf.protection'
	Disables checking of protection block usage and limits for this player. Limits can still be increased/decreased while this is set.
	(This priv is so it can be temporary and we don't have to reset their limit afterwards.)
]]

--[[ End of API ]]--

core.register_privilege('spawnprotection',"Can build inside spawn protection.")
core.register_privilege('inf.protection',"Unlimited protection claim area.")

-- modpath for including more scripts
local modpath = core.get_modpath(core.get_current_modname())..'/'

-- convert autoprotect.chests = {"default:chest"}
-- to autoprotect.chests = {["default:chest"] = true}
-- for easy indexing
for i,v in ipairs(autoprotect.chests) do
	autoprotect.chests[v] = true
	autoprotect.chests[i] = nil
end

-- ensure that autoprotect.vertical_range is properly used
if autoprotect.vertical_range[1] > autoprotect.vertical_range[2] then
	autoprotect.vertical_range = {autoprotect.vertical_range[2], autoprotect.vertical_range[1]}
end

autoprotect.protection = {}
autoprotect.blocks = {}
autoprotect.limits = {}
autoprotect.area = {}
autoprotect.selection = {}

dofile(modpath.."saveload.lua")
autoprotect.read_protection()

function autoprotect.get_areas(pos)
	local ret = {}
	local spawn = false

	if autoprotect.spawn_protection and autoprotect.spawn_protection > 0
	and vector.distance(pos,vector.new(0,pos.y,0)) <= autoprotect.spawn_protection then
		spawn = true
	end

	for _,p in pairs(autoprotect.protection) do
		if p[1] <= pos.x and p[2] <= pos.y and p[3] <= pos.z and
		p[4] >= pos.x and p[5] >= pos.y and p[6] >= pos.z then
			table.insert(ret,p)
		end
	end

	return ret, spawn
end

function autoprotect.is_protected(pos, who, announce)
	local areas, spawn = autoprotect.get_areas(pos)

	-- Check spawn range
	if spawn then
		if core.check_player_privs(who, {spawnprotection=true}) then
			if announce and autoprotect.announce_area and autoprotect.area[who] ~= true then
				core.chat_send_player(who, "Now building inside spawn protection.")
				autoprotect.area[who] = true
			end
		else
			-- Blocked by spawn protection.
			return true
		end
	end

	-- Check for user ranges
	for _,p in pairs(areas) do
		if p.owner ~= who and not p.allowed[who] then
			-- Blocked by owner's protection.
			return true
		elseif announce and autoprotect.announce_area and autoprotect.area[who] ~= p.owner then
			core.chat_send_player(who, "Now building inside "..p.owner.."'s protected area.")
			autoprotect.area[who] = p.owner
		end
	end

	-- Not blocked by anything.
	if announce and not spawn and #areas == 0 and autoprotect.announce_area and autoprotect.area[who] ~= false then
		core.chat_send_player(who, "Now building in unprotected space.")
		autoprotect.area[who] = false
	end
	return false
end

-- Returns _true_ if new_pos does not add any protected areas that pos doesn't have.
-- _false_ if the move crosses into a new protection area.
function autoprotect.protection_match(pos, new_pos)
	if type(new_pos.x) == "number" then
		-- Check spawn protection
		if autoprotect.spawn_protection and autoprotect.spawn_protection > 0 -- spawn protection enabled
		and vector.distance(pos,vector.new(0,pos.y,0)) > autoprotect.spawn_protection -- was not in spawn protection
		and vector.distance(new_pos,vector.new(0,new_pos.y,0)) <= autoprotect.spawn_protection -- crossed into spawn protection
		then
			return false
		end

		-- Check area protections
		for _,p in pairs(autoprotect.protection) do
			-- new_pos is in an area
			if p[1] <= new_pos.x and p[2] <= new_pos.y and p[3] <= new_pos.z and
			p[4] >= new_pos.x and p[5] >= new_pos.y and p[6] >= new_pos.z then
				-- old pos is not in this area
				if p[1] > pos.x or p[2] > pos.y or p[3] > pos.z or
				p[4] < pos.x or p[5] < pos.y or p[6] < new_pos.z then
					-- therefore, the area has been newly crossed into
					return false
				end
			end
		end
	elseif type(new_pos[1]) == "table" then
		-- TODO: Support for new_pos to be an array of many positions to test against pos.
	else
		error("Improper use of autoprotect.protection_match")
	end

	-- Passed!
	return true
end

-- Hook into core.item_place to add notifications for building chests.
local function item_place(itemstack, player, pointed_thing)
	if not autoprotect.chests[itemstack:get_name()] then
		return
	end

	local who = player:get_player_name()
	local protected = false
	local pos = pointed_thing.above
	local areas = autoprotect.get_areas(pos)
	for _,p in pairs(areas) do
		if p.owner ~= who and not p.allowed[who] then
			-- This won't pass through is_protected.
			return ret
		end
		if p.owner ~= who and p.allowed[who] then
			--core.chat_send_player(who, "Warning: Your chest has been placed in "..p.owner.."'s protection area.")
			protected = true
		end
		if p.owner == who then
			protected = true
		end
	end

	if not protected then
		-- automatically claim an area if you haven't claimed any areas yet.
		if autoprotect.firstclaim and (autoprotect.blocks[who] or 0) == 0 then
			autoprotect.claim(who, vector.new(pos.x-autoprotect.firstradius, pos.y, pos.z-autoprotect.firstradius), vector.new(pos.x+autoprotect.firstradius, pos.y, pos.z+autoprotect.firstradius))
			core.chat_send_player(who, "Your first protection area has automatically been placed around this chest.")
			core.chat_send_player(who, "In order to edit the protected area or claim a new selection of land, you'll need to use the /"..autoprotect.command_name.." command to obtain a protection tool.")
		else
			core.chat_send_player(who, "Warning: Your chest has been placed outside of protected areas, where /anyone/ can access and break it.")
		end
	end
end

do
	local super = core.item_place
	function core.item_place(itemstack, placer, pointed_thing, ...)
		return item_place(itemstack, placer, pointed_thing) or super(itemstack, placer, pointed_thing, ...)
	end
end

-- Hook into core.is_protected, but call the superfunction to play nice with other mods.
do
	local super = core.is_protected
	core.is_protected = function(pos, digger, ...) return autoprotect.is_protected(pos, digger, digger ~= "") or super(pos, digger, ...) end
end

-- Report all overlapping protections which we need permissions on.
core.register_on_protection_violation(function(pos, who)
	if not who or who == "" then
		return
	end

	local areas, spawn = autoprotect.get_areas(pos)
	if spawn and not core.check_player_privs(who, {spawnprotection=true}) then
		core.chat_send_player(who, "Blocked by spawn protection.")
	end

	local l = {} -- keep track for a moment so we don't repeat ourselves
	for _,p in pairs(areas) do
		if not l[p.owner] and p.owner ~= who and not p.allowed[who] then
			core.chat_send_player(who, "Blocked by "..p.owner.."'s protection.")
			l[p.owner] = true
		end
	end
end)

--
function autoprotect.claim(who, a, b, fromTool)
	local minp = vector.new(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z))
	local maxp = vector.new(math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z))
	local y = (maxp.y - minp.y) / 2 + minp.y
	minp.y = y + autoprotect.vertical_range[1]
	maxp.y = y + autoprotect.vertical_range[2]

	-- TODO: Check for overlapping protections! X_X

	if not fromTool or not autoprotect.selection[who].area then
		autoprotect.selection[who].area = {minp.x,minp.y,minp.z, maxp.x,maxp.y,maxp.z, owner=who, allowed={}}
		table.insert(autoprotect.protection, autoprotect.selection[who].area)
		autoprotect.blocks[who] = autoprotect.blocks[who] + (maxp.x - minp.x)*(maxp.z - minp.z)
		core.chat_send_player(who, "Area protected.")
	else
		local area = autoprotect.selection[who].area

		local blockdiff = ((maxp.x - minp.x)*(maxp.z - minp.z))-((area[4] - area[1])*(area[6] - area[3]))
		autoprotect.blocks[who] = autoprotect.blocks[who]+blockdiff

		local new_area = {minp.x,minp.y,minp.z,maxp.x,maxp.y,maxp.z}
		for k,v in pairs(new_area) do
			area[k] = v
		end

		core.chat_send_player(who, "Protection updated.")
	end
	autoprotect.save_protection()
end

--
function autoprotect.select_corner(pos, who, which)
	assert(type(which) == "boolean")

	if autoprotect.selection[who] == nil then
		autoprotect.selection[who] = {}
	end

	if which == false then
		autoprotect.selection[who][1] = pos
	elseif which == true then
		autoprotect.selection[who][2] = pos
	end

	-- take both corners and make it into a proper selection
	if autoprotect.selection[who][1] and autoprotect.selection[who][2] then
		autoprotect.claim(who, autoprotect.selection[who][1], autoprotect.selection[who][2], true)
	else
		core.chat_send_player(who, "Selected corner.")
	end
end

function autoprotect.clear_selection(who)
	autoprotect.selection[who] = nil
	core.chat_send_player(who, "Selection cleared.")
end

--[[ In-depth Protection ]]--

-- add a tool for easy point-and-click protection bounds
dofile(modpath.."tool.lua")
-- try to forcefully disable the ability to "use" blocks inside of protected areas
dofile(modpath.."forcedisable.lua")
-- fix falling_node ignoring block protection
dofile(modpath.."mod_builtin.lua")
-- fix mesecons ignoring block protection
if mesecon then dofile(modpath.."mod_mesecons.lua") end
