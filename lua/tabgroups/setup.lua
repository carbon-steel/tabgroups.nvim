local state = require("tabgroups.state")
local M = {}

function M.setup(tabgroups, group_vars, internal)
	tabgroups.tg = group_vars.make_proxy()

	vim.api.nvim_create_user_command("TabGroupMove", function()
		tabgroups.move_current_tab()
	end, { force = true, desc = "Move current tab into a selected tab group" })

	vim.api.nvim_create_user_command("TabGroupNew", function(opts)
		tabgroups.new_group(opts.args ~= "" and opts.args or nil)
	end, {
		force = true,
		desc = "Open a new tab in a new tab group",
		nargs = "?",
	})

	vim.api.nvim_create_user_command("TabGroupRename", function(opts)
		tabgroups.rename_current_group(opts.args ~= "" and opts.args or nil)
	end, { force = true, desc = "Rename the current tab group", nargs = "?" })

	vim.api.nvim_create_user_command("TabGroupClose", function()
		tabgroups.close_current_group()
	end, { force = true, desc = "Close all tabs in the current tab group" })

	-- Core autocmds: group inheritance and focus retention

	local augroup = vim.api.nvim_create_augroup("TabGroups", { clear = true })

	-- Track the group ID and handle of the tab we're leaving
	local last_group_id = nil
	local last_handle = nil

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
			local gid = tabgroups.get_tab_group(handle)
			tabgroups._set_default_tab(gid, handle)
			if last_group_id and last_group_id ~= gid then
				vim.api.nvim_exec_autocmds("User", {
					pattern = "TabGroupEnter",
					data = { id = gid },
				})
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

	-- Session persistence for plugin state
	vim.api.nvim_create_autocmd("SessionWritePost", {
		group = augroup,
		callback = function()
			local lines = {}
			for _, handle in ipairs(vim.api.nvim_list_tabpages()) do
				local tabnr = vim.api.nvim_tabpage_get_number(handle)
				local tab_s = state.tab_all()[handle]
				if tab_s then
					for k, v in pairs(tab_s) do
						table.insert(
							lines,
							string.format(
								"call luaeval(\"require('tabgroups.state').restore_tab(%d, %s, _A)\", %s)",
								tabnr,
								vim.fn.string(k),
								vim.fn.string(v)
							)
						)
					end
				end
			end
			for gid, s in pairs(state.group_all()) do
				for k, v in pairs(s) do
					if k == state.GROUP.DEFAULT_TAB then
						if vim.api.nvim_tabpage_is_valid(v) then
							table.insert(
								lines,
								string.format(
									"call luaeval(\"require('tabgroups.state').restore_group_default_tab(%d, _A)\", %d)",
									gid,
									vim.api.nvim_tabpage_get_number(v)
								)
							)
						end
					else
						table.insert(
							lines,
							string.format(
								"call luaeval(\"require('tabgroups.state').restore_group(%d, %s, _A)\", %s)",
								gid,
								vim.fn.string(k),
								vim.fn.string(v)
							)
						)
					end
				end
			end
			for k, v in pairs(state.global_all()) do
				table.insert(
					lines,
					string.format(
						"call luaeval(\"require('tabgroups.state').global_set(%s, _A)\", %s)",
						vim.fn.string(k),
						vim.fn.string(v)
					)
				)
			end
			if #lines > 0 then
				table.insert(lines, "lua vim.cmd('redrawtabline')")
				vim.fn.writefile(lines, vim.v.this_session, "a")
			end
		end,
	})

	-- After a tab closes, stay in the same group
	vim.api.nvim_create_autocmd("TabClosed", {
		group = augroup,
		callback = function()
			if last_handle then
				state.tab_clear(last_handle)
			end

			if not last_group_id then
				return
			end

			for _, handle in ipairs(vim.api.nvim_list_tabpages()) do
				if tabgroups.get_tab_group(handle) == last_group_id then
					vim.api.nvim_set_current_tabpage(handle)
					return
				end
			end

			-- No tabs remain in the group: clean up its state
			vim.api.nvim_exec_autocmds("User", {
				pattern = "TabGroupClosed",
				data = {
					id = last_group_id,
					name = tabgroups.get_group_name(last_group_id),
				},
			})
			tabgroups._clear_default_tab(last_group_id)
			state.group_clear(last_group_id)
		end,
	})
end

return M
