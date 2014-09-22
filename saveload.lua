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

-- Save protection to world file.
function autoprotect.save_protection(filename)
	if not filename then filename = core.get_worldpath().."/"..autoprotect.db_filename end
	local f = io.open(filename, 'w')
	if not f then
		return false
	end

	if #autoprotect.limits > 0 then
		f:write("#LimitsList\n")
		for k,v in ipairs(autoprotect.limits) do
			f:write(k..":"..v.."\n")
		end
		f:write("#EndList\n")
	end

	for _,p in ipairs(autoprotect.protection) do
		f:write(p[1].." "..p[2].." "..p[3].." "..p[4].." "..p[5].." "..p[6].." "..p.owner.."\n")
		if #p.allowed > 0 then
			f:write("#AllowedList\n")
			for k in pairs(p.allowed) do
				f:write(k.."\n")
			end
			f:write("#EndList\n")
		end
	end
	f:close()
	return true
end

-- Load protection from world file.
function autoprotect.read_protection(filename)
	if not filename then filename = core.get_worldpath().."/"..autoprotect.db_filename end
	local f = io.open(filename, 'r')
	if not f then
		print("[autoprotect] failed to open protection file for this world.")
		return false
	end

	local b = {}
	local t = {}
	local list = 0
	local p
	for l in f:lines() do
		if l:sub(-1) == '\n' then l = l:sub(1,-2) end
		if list == 0 then
			if l == '#LimitsList' then
				list = 2
			elseif p ~= nil and l == '#AllowedList' then
				list = 1
			else
				local x1, y1, z1, x2, y2, z2, owner = l:match("(%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+) (.+)")
				if x1 ~= nil then
					--print("[autoprotect] read area owned by '"..owner.."'")
					p = {tonumber(x1),tonumber(y1),tonumber(z1), tonumber(x2),tonumber(y2),tonumber(z2), owner=owner, allowed={}}
					table.insert(t, p)
					b[owner] = (b[owner] or 0) + (p[4]-p[1])*(p[6]-p[3])
				end
			end
		elseif list == 1 then
			if l == '#EndList' then
				list = 0
			else
				p.allowed[l] = true
			end
		elseif list == 2 then
			if l == '#EndList' then
				list = 0
			else
				local s = l:find(':',1,true)
				autoprotect.limits[l:sub(1,s-1)] = tonumber(l:sub(s+1))
			end
		end
	end
	f:close()

	autoprotect.protection = t
	autoprotect.blocks = b

	print("[autoprotect] Protection counts:")
	for k,v in pairs(b) do
		print("[autoprotect] "..k..": "..v)
	end

	return true
end
