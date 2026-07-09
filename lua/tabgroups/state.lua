local M = {}

M.TAB = { ID = 1 }
M.GROUP = { NAME = 1, DEFAULT_TAB = 2 }
M.GLOBAL = { COUNTER = 1 }

local tab = {}    -- handle -> { key -> value }
local group = {}  -- gid -> { key -> value }
local global = {} -- key -> value

function M.tab_get(handle, key)
	local t = tab[handle]
	return t and t[key]
end

function M.tab_set(handle, key, value)
	if not tab[handle] then
		tab[handle] = {}
	end
	tab[handle][key] = value
end

function M.tab_del(handle, key)
	if tab[handle] then
		tab[handle][key] = nil
	end
end

function M.tab_clear(handle)
	tab[handle] = nil
end

function M.tab_all()
	return tab
end

function M.group_get(gid, key)
	local g = group[gid]
	return g and g[key]
end

function M.group_set(gid, key, value)
	if not group[gid] then
		group[gid] = {}
	end
	group[gid][key] = value
end

function M.group_del(gid, key)
	if group[gid] then
		group[gid][key] = nil
	end
end

function M.group_clear(gid)
	group[gid] = nil
end

function M.group_all()
	return group
end

function M.global_get(key)
	return global[key]
end

function M.global_set(key, value)
	global[key] = value
end

function M.global_del(key)
	global[key] = nil
end

function M.global_all()
	return global
end

-- Called from session restore: maps tabnr (1-based) to a handle at restore time.
function M.restore_tab(tabnr, key, value)
	local handle = vim.api.nvim_list_tabpages()[tabnr]
	if handle then
		M.tab_set(handle, key, value)
	end
end

function M.restore_group(gid, key, value)
	M.group_set(gid, key, value)
end

function M.restore_group_default_tab(gid, tabnr)
	local handle = vim.api.nvim_list_tabpages()[tabnr]
	if handle then
		M.group_set(gid, M.GROUP.DEFAULT_TAB, handle)
	end
end

return M
