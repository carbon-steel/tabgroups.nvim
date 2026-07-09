local tabgroups

describe("tabgroups", function()
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
	-- list_groups
	-- -------------------------------------------------------------------------
	describe("list_groups", function()
		after_each(function()
			while vim.fn.tabpagenr("$") > 1 do
				vim.cmd("tabclose $")
			end
		end)

		it("returns a single entry when only one group exists", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			local groups = tabgroups.list_groups()
			assert.are.same(1, #groups)
			assert.are.same(gid, groups[1].id)
			assert.is_nil(groups[1].name)
			assert.are.same(
				{ vim.api.nvim_get_current_tabpage() },
				groups[1].tabs
			)
		end)

		it(
			"returns one entry per distinct group, ordered by first tab",
			function()
				local tab_a = vim.api.nvim_get_current_tabpage()
				local gid_a = tabgroups.get_tab_group(tab_a)
				tabgroups.new_group("B")
				local gid_b =
					tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
				local groups = tabgroups.list_groups()
				assert.are.same(2, #groups)
				assert.are.same(gid_a, groups[1].id)
				assert.are.same(gid_b, groups[2].id)
				assert.are.same("B", groups[2].name)
			end
		)
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

		it(
			"warns and does not close any tabs when it is the only group",
			function()
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
			end
		)

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
