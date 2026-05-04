local tabgroups

describe("tabgroups", function()
	before_each(function()
		-- Reload to reset module-level state (group_names, tab_groups tables)
		package.loaded["tabgroups"] = nil
		package.loaded["tabgroups.group_variables"] = nil
		package.loaded["tabgroups.internal"] = nil
		package.loaded["tabgroups.setup"] = nil
		tabgroups = require("tabgroups")
		-- Source the plugin to register autocmds (TabNew, TabEnter, etc.) and tabgroups.tg
		vim.cmd("source plugin/tabgroups.lua")
	end)

	-- -------------------------------------------------------------------------
	-- tab group assignment
	-- -------------------------------------------------------------------------
	describe("tab group assignment", function()
		it("auto-assigns a gid on first use", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			assert.is_true(type(gid) == "number" and gid > 0)
		end)

		it("assigned gid is stable across calls", function()
			assert.are.same(
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage()),
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- group names
	-- -------------------------------------------------------------------------
	describe("group names", function()
		it("unnamed group shows gid-based fallback name", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			assert.is_true(tabgroups.tabline():find("Tab Group " .. gid) ~= nil)
		end)

		it("renamed group shows explicit name instead of fallback", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			tabgroups.rename_current_group("frontend")
			local line = tabgroups.tabline()
			assert.is_true(line:find("frontend") ~= nil)
			assert.is_nil(line:find("Tab Group " .. gid))
		end)
	end)

	-- -------------------------------------------------------------------------
	-- tab groups in tabline right section
	-- -------------------------------------------------------------------------
	describe("tab groups in tabline", function()
		after_each(function()
			while vim.fn.tabpagenr("$") > 1 do
				vim.cmd("tabclose $")
			end
		end)

		it("shows one group when all tabs share a gid", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			vim.cmd("tabnew") -- inherits current group via TabNew autocmd
			vim.cmd("tabnew")
			local _, count = tabgroups.tabline():gsub("Tab Group " .. gid, "")
			assert.are.same(1, count)
		end)

		it("shows a separate group entry for each distinct gid", function()
			local gid1 =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			tabgroups.new_group("group2")
			local line = tabgroups.tabline()
			assert.is_true(line:find("Tab Group " .. gid1) ~= nil)
			assert.is_true(line:find("group2") ~= nil)
		end)

		it("groups appear ordered by their first tab", function()
			local tab_a = vim.api.nvim_get_current_tabpage()
			local gid_a = tabgroups.get_tab_group(tab_a)
			tabgroups.new_group("B") -- new tab in B
			vim.api.nvim_set_current_tabpage(tab_a) -- back to A
			vim.cmd("tabnew") -- new tab in A; B's tab shifts right
			local line = tabgroups.tabline()
			assert.is_true(line:find("Tab Group " .. gid_a) < line:find(" B "))
		end)

		it("two groups show distinct entries in tabline", function()
			local gid1 =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			tabgroups.new_group("second")
			local line = tabgroups.tabline()
			assert.is_true(line:find("Tab Group " .. gid1) ~= nil)
			assert.is_true(line:find("second") ~= nil)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- tabline rendering
	-- -------------------------------------------------------------------------
	describe("tabline rendering", function()
		after_each(function()
			while vim.fn.tabpagenr("$") > 1 do
				vim.cmd("tabclose $")
			end
		end)

		it("returns a non-empty string", function()
			assert.is_true(#tabgroups.tabline() > 0)
		end)

		it("uses TabLineSel highlight for the current tab", function()
			vim.api.nvim_buf_set_name(0, "current.lua")
			local line = tabgroups.tabline()
			vim.api.nvim_buf_set_name(0, "")
			-- TabLineSel must appear before current.lua (left section),
			-- not only in the right section where it highlights the current group.
			assert.is_true(line:find("%%#TabLineSel#.-current%.lua") ~= nil)
		end)

		it("contains TabLineFill highlight", function()
			assert.is_true(tabgroups.tabline():find("TabLineFill") ~= nil)
		end)

		it("contains right-align separator", function()
			local line = tabgroups.tabline()
			assert.is_true(line:find("%%=") ~= nil or line:find("%=") ~= nil)
		end)

		it(
			"shows TabLine highlight for non-current tabs in the same group",
			function()
				assert.is_false(tabgroups.tabline():find("%%#TabLine#") ~= nil)
				vim.cmd("tabnew") -- second tab in same group; first tab becomes non-current
				assert.is_true(tabgroups.tabline():find("%%#TabLine#") ~= nil)
			end
		)

		it("shows modified marker for a modified buffer", function()
			assert.is_false(tabgroups.tabline():find("●") ~= nil)
			vim.bo.modified = true
			local line = tabgroups.tabline()
			vim.bo.modified = false
			assert.is_true(line:find("●") ~= nil)
		end)

		it("shows the filename for a named buffer", function()
			assert.is_false(tabgroups.tabline():find("myfile.lua") ~= nil)
			vim.api.nvim_buf_set_name(0, "myfile.lua")
			local line = tabgroups.tabline()
			vim.api.nvim_buf_set_name(0, "")
			assert.is_true(line:find("myfile.lua") ~= nil)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- next_tab_in_group / prev_tab_in_group
	-- -------------------------------------------------------------------------
	describe("next_tab_in_group / prev_tab_in_group", function()
		after_each(function()
			while vim.fn.tabpagenr("$") > 1 do
				vim.cmd("tabclose $")
			end
		end)

		-- Note: with 1 tab the modulo arithmetic wraps back to the same index, so
		-- removing the early-return guard produces identical observable behavior.
		-- This test verifies the correct outcome, not the guard's presence.
		it("does nothing with a single tab in the group", function()
			local tab = vim.api.nvim_get_current_tabpage()
			tabgroups.next_tab_in_group()
			assert.are.same(tab, vim.api.nvim_get_current_tabpage())
			tabgroups.prev_tab_in_group()
			assert.are.same(tab, vim.api.nvim_get_current_tabpage())
		end)

		it(
			"next_tab_in_group cycles forward through tabs in the group",
			function()
				local tab1 = vim.api.nvim_get_current_tabpage()
				vim.cmd("tabnew")
				local tab2 = vim.api.nvim_get_current_tabpage()
				vim.cmd("tabnew")
				local tab3 = vim.api.nvim_get_current_tabpage()
				vim.api.nvim_set_current_tabpage(tab1)
				-- With 3 tabs, forward from tab1→tab2→tab3 is distinct from backward (tab1→tab3→tab2)
				tabgroups.next_tab_in_group()
				assert.are.same(tab2, vim.api.nvim_get_current_tabpage())
				tabgroups.next_tab_in_group()
				assert.are.same(tab3, vim.api.nvim_get_current_tabpage())
				tabgroups.next_tab_in_group()
				assert.are.same(tab1, vim.api.nvim_get_current_tabpage())
			end
		)

		it(
			"prev_tab_in_group cycles backward through tabs in the group",
			function()
				local tab1 = vim.api.nvim_get_current_tabpage()
				vim.cmd("tabnew")
				local tab2 = vim.api.nvim_get_current_tabpage()
				vim.cmd("tabnew")
				local tab3 = vim.api.nvim_get_current_tabpage()
				-- With 3 tabs, backward from tab3→tab2→tab1 is distinct from forward (tab3→tab1→tab2)
				tabgroups.prev_tab_in_group()
				assert.are.same(tab2, vim.api.nvim_get_current_tabpage())
				tabgroups.prev_tab_in_group()
				assert.are.same(tab1, vim.api.nvim_get_current_tabpage())
				tabgroups.prev_tab_in_group()
				assert.are.same(tab3, vim.api.nvim_get_current_tabpage())
			end
		)

		it("only cycles through tabs in the current group", function()
			local tab_a1 = vim.api.nvim_get_current_tabpage()
			tabgroups.new_group("B") -- tab_b in a different group
			vim.api.nvim_set_current_tabpage(tab_a1)
			vim.cmd("tabnew") -- tab_a2 in the same group as tab_a1
			local tab_a2 = vim.api.nvim_get_current_tabpage()
			vim.api.nvim_set_current_tabpage(tab_a1)
			tabgroups.next_tab_in_group()
			assert.are.same(tab_a2, vim.api.nvim_get_current_tabpage())
			tabgroups.next_tab_in_group() -- wraps back to tab_a1
			assert.are.same(tab_a1, vim.api.nvim_get_current_tabpage())
		end)
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

		it("closing tab6 after navigating from tab2 returns to tab2", function()
			-- Create a 6-tab group
			vim.cmd("tabnew")
			local tab2 = vim.api.nvim_get_current_tabpage()
			vim.cmd("tabnew")
			vim.cmd("tabnew")
			vim.cmd("tabnew")
			vim.cmd("tabnew")
			local tab6 = vim.api.nvim_get_current_tabpage()
			-- Go to tab2, then jump directly to tab6
			vim.api.nvim_set_current_tabpage(tab2)
			vim.api.nvim_set_current_tabpage(tab6)
			vim.cmd("tabclose") -- close tab6; should return to tab2
			assert.are.same(tab2, vim.api.nvim_get_current_tabpage())
		end)
	end)

	-- -------------------------------------------------------------------------
	-- close_current_group
	-- -------------------------------------------------------------------------
	describe("close_current_group", function()
		after_each(function()
			while vim.fn.tabpagenr("$") > 1 do
				vim.cmd("tabclose $")
			end
		end)

		it("warns and does not close any tabs when it is the only group", function()
			vim.cmd("tabnew")
			local warned = false
			local orig = vim.notify
			vim.notify = function(_, level)
				if level == vim.log.levels.WARN then
					warned = true
				end
			end
			tabgroups.close_current_group()
			vim.notify = orig
			assert.is_true(warned)
			assert.are.same(2, vim.fn.tabpagenr("$"))
		end)

		it("closes all tabs in the current group", function()
			local tab_a1 = vim.api.nvim_get_current_tabpage()
			vim.cmd("tabnew") -- tab_a2 inherits group A
			tabgroups.new_group("B")
			local tab_b1 = vim.api.nvim_get_current_tabpage()
			vim.api.nvim_set_current_tabpage(tab_a1)
			tabgroups.close_current_group()
			assert.are.same({ tab_b1 }, vim.api.nvim_list_tabpages())
		end)

		it("lands in another group after closing", function()
			local tab_a = vim.api.nvim_get_current_tabpage()
			tabgroups.new_group("B")
			local gid_b =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			vim.api.nvim_set_current_tabpage(tab_a)
			tabgroups.close_current_group()
			assert.are.same(
				gid_b,
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			)
		end)

		it("removes the closed group from the tabline", function()
			local tab_a = vim.api.nvim_get_current_tabpage()
			tabgroups.rename_current_group("alpha")
			tabgroups.new_group("beta")
			vim.api.nvim_set_current_tabpage(tab_a)
			tabgroups.close_current_group()
			local line = tabgroups.tabline()
			assert.is_nil(line:find("alpha"))
			assert.is_truthy(line:find("beta"))
		end)

		it("fires TabGroupClosed for the closed group", function()
			local tab_a = vim.api.nvim_get_current_tabpage()
			local gid_a = tabgroups.get_tab_group(tab_a)
			tabgroups.new_group("B")
			vim.api.nvim_set_current_tabpage(tab_a)
			local closed_id = nil
			vim.api.nvim_create_autocmd("User", {
				pattern = "TabGroupClosed",
				once = true,
				callback = function(ev)
					closed_id = ev.data.id
				end,
			})
			tabgroups.close_current_group()
			assert.are.same(gid_a, closed_id)
		end)
	end)
end)
