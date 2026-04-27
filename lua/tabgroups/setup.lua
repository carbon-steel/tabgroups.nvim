local M = {}

function M.setup(tabgroups, group_vars, internal)

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

	-- Track the group ID and handle of the tab we're leaving
	local last_group_id = nil
	local last_handle = nil

	-- Maps tab handle → the tab that navigated to it (most recent)
	local tab_predecessor = {}

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
			local handle = vim.api.nvim_get_current_tabpage()
			tabgroups._set_default_tab(tabgroups.get_tab_group(handle), handle)
			if last_handle and last_handle ~= handle then
				tab_predecessor[handle] = last_handle
			end
		end,
	})

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
			-- Save predecessor before clearing the closed tab's entries
			local pred = last_handle and tab_predecessor[last_handle]

			-- Remove the closed tab's group entry and predecessor record
			if last_handle then
				tabgroups._set_tab_group(last_handle, nil)
				tab_predecessor[last_handle] = nil
			end

			if not last_group_id then
				return
			end

			local current_gid = tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())

			if current_gid == last_group_id then
				-- Same group: return to the tab we navigated from, if still valid
				if pred
					and vim.api.nvim_tabpage_is_valid(pred)
					and tabgroups.get_tab_group(pred) == last_group_id
				then
					vim.api.nvim_set_current_tabpage(pred)
				end
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
				tabgroups._clear_default_tab(last_group_id)
				vim.tg.clear(last_group_id)
			end
		end,
	})
end

return M
