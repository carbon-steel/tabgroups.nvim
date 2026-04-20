local tabgroups = require("tabgroups")
local group_vars = require("tabgroups.group_variables")

vim.tg = group_vars.make_proxy(function()
	return tabgroups._get_tab_group(vim.fn.tabpagenr())
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
		local tabnr = vim.fn.tabpagenr()
		local gid = tabgroups._get_tab_group(tabnr)
		group_vars.set(gid, "_default_tab", tabnr)
	end,
})

-- Track the group ID of the tab we're leaving
local last_group_id = nil

vim.api.nvim_create_autocmd("TabLeave", {
	group = augroup,
	callback = function()
		last_group_id = tabgroups._get_tab_group(vim.fn.tabpagenr())
	end,
})

-- New tabs inherit the group of the tab they were opened from
-- (TabGroupNew overrides this via vim.g.tab_group_new_override)
vim.api.nvim_create_autocmd("TabNew", {
	group = augroup,
	callback = function()
		local gid = vim.g.tab_group_new_override
			or last_group_id
			or tabgroups._new_group_id()
		tabgroups._set_tab_group(vim.fn.tabpagenr(), gid)
	end,
})

-- After a tab closes, stay in the same group
vim.api.nvim_create_autocmd("TabClosed", {
	group = augroup,
	callback = function()
		if not last_group_id then
			return
		end

		local current_gid = tabgroups._get_tab_group(vim.fn.tabpagenr())

		if current_gid == last_group_id then
			return
		end

		for tabnr = 1, vim.fn.tabpagenr("$") do
			if tabgroups._get_tab_group(tabnr) == last_group_id then
				vim.cmd("tabnext " .. tabnr)
				break
			end
		end

		-- Clear state when the last tab of a group closes
		local group_still_exists = false
		for tabnr = 1, vim.fn.tabpagenr("$") do
			if tabgroups._get_tab_group(tabnr) == last_group_id then
				group_still_exists = true
				break
			end
		end
		if not group_still_exists then
			group_vars.clear(last_group_id)
		end
	end,
})
