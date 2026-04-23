-- Per-tab-group key-value storage, accessed via vim.tg
-- vim.tg.foo          → get key "foo" from current group
-- vim.tg.foo = val    → set key "foo" in current group
-- vim.tg[3]           → proxy table for gid 3
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

-- make_proxy(get_current_gid_fn) returns the vim.tg table.
-- get_current_gid_fn is called at access time so the proxy always reflects
-- the current tab group.
-- vim.tg.clear(gid) clears all variables for a group.
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

return M
