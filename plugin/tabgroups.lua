local tabgroups = require("tabgroups")
local group_vars = require("tabgroups.group_variables")
local internal = require("tabgroups.internal")

vim.tg = group_vars.make_proxy(function()
	return tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
end)

vim.api.nvim_create_user_command("TabGroupMove", function()
	tabgroups.move_current_tab()
end, { desc = "Move current tab into a selected tab group" })

vim.api.nvim_create_user_command("TabGroupNew", function(opts)
	tabgroups.new_group(opts.args ~= "" and opts.args or nil)
end, { desc = "Open a new tab in a new tab group", nargs = "?" })

vim.api.nvim_create_user_command("TabGroupRename", function(opts)
	tabgroups.rename_current_group(opts.args ~= "" and opts.args or nil)
end, { desc = "Rename the current tab group", nargs = "?" })

-- Core autocmds: group inheritance and focus retention

local augroup = vim.api.nvim_create_augroup("TabGroups", { clear = true })

-- Refresh tabline when tab layout changes
vim.api.nvim_create_autocmd(
	{ "DirChanged", "TabEnter", "TabNew", "TabClosed" },
	{
		group = augroup,
		callback = function()
			vim.cmd("redrawtabline")
		end,
	}
)

-- Track the most recently active tab per group so next_tab_group / prev_tab_group
-- can return to the last-used tab rather than always the first.
vim.api.nvim_create_autocmd("TabEnter", {
	group = augroup,
	callback = function()
		vim.tg._default_tab = vim.api.nvim_get_current_tabpage()
	end,
})

-- Track the group ID and handle of the tab we're leaving
local last_group_id = nil
local last_handle = nil

vim.api.nvim_create_autocmd("TabLeave", {
	group = augroup,
	callback = function()
		last_handle = vim.api.nvim_get_current_tabpage()
		last_group_id = tabgroups.get_tab_group(last_handle)
	end,
})

-- New tabs inherit the group of the tab they were opened from
-- (TabGroupNew overrides this via internal.new_group_override)
vim.api.nvim_create_autocmd("TabNew", {
	group = augroup,
	callback = function()
		local gid = internal.new_group_override
			or last_group_id
			or tabgroups._new_group_id()
		tabgroups._set_tab_group(vim.api.nvim_get_current_tabpage(), gid)
	end,
})

-- After a tab closes, stay in the same group
vim.api.nvim_create_autocmd("TabClosed", {
	group = augroup,
	callback = function()
		-- Remove the closed tab's group entry
		if last_handle then
			tabgroups._set_tab_group(last_handle, nil)
		end

		if not last_group_id then
			return
		end

		local current_gid = tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())

		if current_gid == last_group_id then
			return
		end

		for _, handle in ipairs(vim.api.nvim_list_tabpages()) do
			if tabgroups.get_tab_group(handle) == last_group_id then
				vim.api.nvim_set_current_tabpage(handle)
				break
			end
		end

		-- Clear state when the last tab of a group closes
		local group_still_exists = false
		for _, handle in ipairs(vim.api.nvim_list_tabpages()) do
			if tabgroups.get_tab_group(handle) == last_group_id then
				group_still_exists = true
				break
			end
		end
		if not group_still_exists then
			vim.api.nvim_exec_autocmds("User", {
				pattern = "TabGroupClosed",
				data = { id = last_group_id, name = tabgroups.get_group_name(last_group_id) },
			})
			vim.tg.clear(last_group_id)
		end
	end,
})
