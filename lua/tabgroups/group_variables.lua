-- Per-tab-group key-value storage, accessed via require("tabgroups").tg
-- tg.foo          → get key "foo" from current group
-- tg.foo = val    → set key "foo" in current group
-- tg[3]           → proxy table for gid 3
local M = {}
local state = require("tabgroups.state")

local proxies = {} -- gid -> proxy table (cached)

local function current_gid()
	return state.tab_get(vim.api.nvim_get_current_tabpage(), state.TAB.ID)
end

local function validate_key(key)
	if tonumber(key) ~= nil then
		error("tabgroups: group variable key must not be numeric, got: " .. tostring(key), 3)
	end
end

local function group_proxy(gid)
	if not proxies[gid] then
		proxies[gid] = setmetatable({}, {
			__index = function(_, key)
				validate_key(key)
				return state.group_get(gid, key)
			end,
			__newindex = function(_, key, value)
				validate_key(key)
				state.group_set(gid, key, value)
			end,
		})
	end
	return proxies[gid]
end

function M.make_proxy()
	return setmetatable({}, {
		__index = function(_, key)
			if type(key) == "number" then
				return group_proxy(key)
			end
			validate_key(key)
			return state.group_get(current_gid(), key)
		end,
		__newindex = function(_, key, value)
			validate_key(key)
			state.group_set(current_gid(), key, value)
		end,
	})
end

return M
