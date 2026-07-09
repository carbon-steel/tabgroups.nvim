local tabgroups

describe("navigation memory", function()
	before_each(function()
		for name in pairs(package.loaded) do
			if vim.startswith(name, "tabgroups") then
				package.loaded[name] = nil
			end
		end
		tabgroups = require("tabgroups")
		vim.cmd("source plugin/tabgroups.lua")
	end)

	-- -------------------------------------------------------------------------
	-- _default_tab: group navigation target
	-- -------------------------------------------------------------------------
	describe("_default_tab", function()
		after_each(function()
			while vim.fn.tabpagenr("$") > 1 do
				vim.cmd("tabclose $")
			end
		end)

		it("next_tab_group does nothing when only one group exists", function()
			local tab = vim.api.nvim_get_current_tabpage()
			tabgroups.next_tab_group()
			assert.are.same(tab, vim.api.nvim_get_current_tabpage())
		end)

		it("prev_tab_group does nothing when only one group exists", function()
			local tab = vim.api.nvim_get_current_tabpage()
			tabgroups.prev_tab_group()
			assert.are.same(tab, vim.api.nvim_get_current_tabpage())
		end)

		it("next_tab_group returns to last visited tab in group", function()
			local tab_a = vim.api.nvim_get_current_tabpage()
			tabgroups.new_group("B") -- new tab B1
			local tab_b1 = vim.api.nvim_get_current_tabpage()
			vim.cmd("tabnew") -- another tab B2; _default_tab[B] = B2
			local tab_b2 = vim.api.nvim_get_current_tabpage()

			-- last visited B1 → next_tab_group lands on B1
			vim.api.nvim_set_current_tabpage(tab_b1)
			vim.api.nvim_set_current_tabpage(tab_a)
			tabgroups.next_tab_group()
			assert.are.same(tab_b1, vim.api.nvim_get_current_tabpage())

			-- last visited B2 → next_tab_group lands on B2
			vim.api.nvim_set_current_tabpage(tab_b2)
			vim.api.nvim_set_current_tabpage(tab_a)
			tabgroups.next_tab_group()
			assert.are.same(tab_b2, vim.api.nvim_get_current_tabpage())
		end)

		it("prev_tab_group returns to last visited tab in group", function()
			local tab_a1 = vim.api.nvim_get_current_tabpage()
			vim.cmd("tabnew")
			local tab_a2 = vim.api.nvim_get_current_tabpage()
			tabgroups.new_group("B")
			local tab_b = vim.api.nvim_get_current_tabpage()

			-- last visited A1 → prev_tab_group lands on A1
			vim.api.nvim_set_current_tabpage(tab_a1)
			vim.api.nvim_set_current_tabpage(tab_b)
			tabgroups.prev_tab_group()
			assert.are.same(tab_a1, vim.api.nvim_get_current_tabpage())

			-- last visited A2 → prev_tab_group lands on A2
			vim.api.nvim_set_current_tabpage(tab_a2)
			vim.api.nvim_set_current_tabpage(tab_b)
			tabgroups.prev_tab_group()
			assert.are.same(tab_a2, vim.api.nvim_get_current_tabpage())
		end)

		it(
			"next_tab_group falls back to first_tab when _default_tab was moved to another group",
			function()
				local tab_a = vim.api.nvim_get_current_tabpage()
				tabgroups.new_group("B") -- new tab in B
				local tab_b1 = vim.api.nvim_get_current_tabpage()
				vim.cmd("tabnew") -- another tab in B; TabEnter → _default_tab[B] = this tab
				local tab_b2 = vim.api.nvim_get_current_tabpage()
				vim.api.nvim_set_current_tabpage(tab_a) -- back to A
				vim.api.nvim_set_current_tabpage(tab_b2) -- go to tab_b2 (B)
				local gid_a = tabgroups.get_tab_group(tab_a)
				tabgroups.move_current_tab(gid_a) -- tab_b2 → group A; _default_tab[B] becomes stale
				vim.api.nvim_set_current_tabpage(tab_a) -- back to A
				tabgroups.next_tab_group() -- stale _default_tab → falls back to first tab in B
				assert.are.same(tab_b1, vim.api.nvim_get_current_tabpage())
			end
		)
	end)

	-- -------------------------------------------------------------------------
	-- TabClosed: group membership after tab close
	-- -------------------------------------------------------------------------
	describe("TabClosed", function()
		after_each(function()
			while vim.fn.tabpagenr("$") > 1 do
				vim.cmd("tabclose $")
			end
		end)

		it(
			"closing a tab in the current group stays in the same group",
			function()
				local gid =
					tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
				vim.cmd("tabnew") -- second tab, same group
				vim.cmd("tabclose") -- close second tab; Neovim moves to first (same group)
				assert.are.same(
					gid,
					tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
				)
			end
		)

		it(
			"closing a tab navigates back when Neovim lands in a different group",
			function()
				local tab_a1 = vim.api.nvim_get_current_tabpage() -- A at pos 1
				local gid_a = tabgroups.get_tab_group(tab_a1)
				tabgroups.new_group("B") -- tab_b at pos 2
				vim.cmd("tabnew") -- pos 3, inherits B's gid
				local tab_a2 = vim.api.nvim_get_current_tabpage()
				tabgroups.move_current_tab(gid_a) -- reassign to group A
				-- layout: [A1(pos1), B(pos2), A2(pos3)]
				vim.api.nvim_set_current_tabpage(tab_a1)
				vim.cmd("tabclose") -- close A1 (pos 1); Neovim moves right to B (new pos 1)
				-- handler: last=A, current=B → navigate to remaining A tab (tab_a2)
				assert.are.same(tab_a2, vim.api.nvim_get_current_tabpage())
			end
		)

		it("closing the last tab of a group clears its group state", function()
			tabgroups.new_group("B")
			local gid_b =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			tabgroups.tg[gid_b].marker = "set"
			vim.cmd("tabclose") -- close the only B tab; group B no longer exists
			assert.is_nil(tabgroups.tg[gid_b].marker)
		end)

		it(
			"fires TabGroupClosed with id and name when the last tab of a group closes",
			function()
				tabgroups.new_group("my-group")
				local gid_b =
					tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
				tabgroups.tg[gid_b].foo = "bar"
				local event_data = nil
				local vars_at_fire = nil
				vim.api.nvim_create_autocmd("User", {
					pattern = "TabGroupClosed",
					once = true,
					callback = function(ev)
						event_data = ev.data
						vars_at_fire = tabgroups.tg[gid_b].foo
					end,
				})
				vim.cmd("tabclose")
				assert.are.same(gid_b, event_data.id)
				assert.are.same("my-group", event_data.name)
				assert.are.same("bar", vars_at_fire)
			end
		)

		it(
			"does not fire TabGroupClosed when the group still has tabs",
			function()
				vim.cmd("tabnew") -- second tab in the same group
				local fired = false
				vim.api.nvim_create_autocmd("User", {
					pattern = "TabGroupClosed",
					once = true,
					callback = function()
						fired = true
					end,
				})
				vim.cmd("tabclose")
				assert.is_false(fired)
			end
		)

		it(
			"fires TabGroupEnter with id when switching to a different group",
			function()
				local tab_a = vim.api.nvim_get_current_tabpage()
				tabgroups.new_group("group-b")
				local gid_b =
					tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
				local tab_b = vim.api.nvim_get_current_tabpage()
				vim.api.nvim_set_current_tabpage(tab_a) -- go back to group A
				local event_data = nil
				vim.api.nvim_create_autocmd("User", {
					pattern = "TabGroupEnter",
					once = true,
					callback = function(ev)
						event_data = ev.data
					end,
				})
				vim.api.nvim_set_current_tabpage(tab_b) -- enter group B
				assert.are.same(gid_b, event_data.id)
			end
		)

		it(
			"does not fire TabGroupEnter when switching within the same group",
			function()
				vim.cmd("tabnew") -- same group
				local tab2 = vim.api.nvim_get_current_tabpage()
				vim.cmd("tabnew")
				local tab3 = vim.api.nvim_get_current_tabpage()
				vim.api.nvim_set_current_tabpage(tab2)
				local fired = false
				vim.api.nvim_create_autocmd("User", {
					pattern = "TabGroupEnter",
					once = true,
					callback = function()
						fired = true
					end,
				})
				vim.api.nvim_set_current_tabpage(tab3)
				assert.is_false(fired)
			end
		)

		it("closing a tab stays within the same group", function()
			-- Create a 6-tab group
			vim.cmd("tabnew")
			local tab2 = vim.api.nvim_get_current_tabpage()
			vim.cmd("tabnew")
			vim.cmd("tabnew")
			vim.cmd("tabnew")
			vim.cmd("tabnew")
			local tab6 = vim.api.nvim_get_current_tabpage()
			local gid = tabgroups.get_tab_group(tab6)
			-- Go to tab2, then jump directly to tab6
			vim.api.nvim_set_current_tabpage(tab2)
			vim.api.nvim_set_current_tabpage(tab6)
			vim.cmd("tabclose") -- close tab6; should land on any tab in the same group
			assert.are.same(
				gid,
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			)
		end)

		it("clears all tab state when a tab is closed", function()
			local state = require("tabgroups.state")
			local tab = vim.api.nvim_get_current_tabpage()
			tabgroups.get_tab_group(tab)
			vim.cmd("tabnew")
			vim.api.nvim_set_current_tabpage(tab)
			assert.is_not_nil(state.tab_get(tab, state.TAB.ID))
			vim.cmd("tabclose")
			assert.is_nil(state.tab_get(tab, state.TAB.ID))
		end)

		it("clears all group state when the last tab of a group is closed", function()
			local state = require("tabgroups.state")
			tabgroups.new_group("B")
			local gid_b =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			state.group_set(gid_b, "custom", "data")
			vim.cmd("tabclose")
			assert.is_nil(state.group_get(gid_b, state.GROUP.NAME))
			assert.is_nil(state.group_get(gid_b, "custom"))
		end)
	end)
end)
