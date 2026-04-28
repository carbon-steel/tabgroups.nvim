-- Per-tab-group key-value storage, accessed via require("tabgroups").tg
-- tg.foo          → get key "foo" from current group
-- tg.foo = val    → set key "foo" in current group
-- tg[3]           → proxy table for gid 3
local M = {}

local group_vars = {} -- gid -> { key -> value }
local proxies = {} -- gid -> proxy table (cached)

function M.get(gid, key)
	if not group_vars[gid] then
		return nil
	end
	return group_vars[gid][key]
end

function M.set(gid, key, value)
	if not group_vars[gid] then
		group_vars[gid] = {}
	end
	group_vars[gid][key] = value
end

function M.clear(gid)
	group_vars[gid] = nil
	proxies[gid] = nil
end

local function group_proxy(gid)
	if not proxies[gid] then
		proxies[gid] = setmetatable({}, {
			__index = function(_, key)
				return M.get(gid, key)
			end,
			__newindex = function(_, key, value)
				M.set(gid, key, value)
			end,
		})
	end
	return proxies[gid]
end

-- make_proxy(get_current_gid_fn) returns the tg proxy table.
-- get_current_gid_fn is called at access time so the proxy always reflects
-- the current tab group.
-- tg.clear(gid) clears all variables for a group.
function M.make_proxy(get_current_gid)
	return setmetatable({}, {
		__index = function(_, key)
			if key == "clear" then
				return M.clear
			end
			if type(key) == "number" then
				return group_proxy(key)
			end
			return M.get(get_current_gid(), key)
		end,
		__newindex = function(_, key, value)
			M.set(get_current_gid(), key, value)
		end,
	})
end

-- Merges file vars into the group. Keys not in the file are left untouched.
-- on_conflict(key, existing, incoming) → value to keep, called only for keys
-- that exist in both the file and the current group. When omitted, the
-- incoming value from the file wins.
function M.load(gid, filepath, on_conflict)
	local ok, lines = pcall(vim.fn.readfile, filepath)
	if not ok then
		return false, lines
	end
	local json = table.concat(lines, "")
	local ok2, vars = pcall(vim.fn.json_decode, json)
	if not ok2 then
		return false, vars
	end
	if type(vars) ~= "table" then
		return false, "expected a JSON object"
	end
	if not group_vars[gid] then
		group_vars[gid] = {}
	end
	for k, v in pairs(vars) do
		if group_vars[gid][k] ~= nil and on_conflict then
			group_vars[gid][k] = on_conflict(k, group_vars[gid][k], v)
		else
			group_vars[gid][k] = v
		end
	end
	proxies[gid] = nil
	return true
end

function M.snapshot(gid)
	local function deep_copy(t)
		local copy = {}
		for k, v in pairs(t) do
			copy[k] = type(v) == "table" and deep_copy(v) or v
		end
		return copy
	end
	return deep_copy(group_vars[gid] or {})
end

function M.save(gid, filepath)
	local vars = group_vars[gid] or {}
	local json = vim.fn.json_encode(vars)
	local ok, result = pcall(vim.fn.writefile, { json }, filepath)
	if not ok then
		return false, result
	end
	return result == 0
end

return M
