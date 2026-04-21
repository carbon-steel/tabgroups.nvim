local tabgroups

describe("tabgroups", function()
	before_each(function()
		-- Reload to reset module-level state (group_names, tab_groups tables)
		package.loaded["tabgroups"] = nil
		package.loaded["tabgroups.group_variables"] = nil
		package.loaded["tabgroups.internal"] = nil
		tabgroups = require("tabgroups")
		-- Source the plugin to register autocmds (TabNew, TabEnter, etc.) and vim.tg
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
		it("returns a non-empty string", function()
			assert.is_true(#tabgroups.tabline() > 0)
		end)

		it("contains TabLineSel highlight", function()
			assert.is_true(tabgroups.tabline():find("TabLineSel") ~= nil)
		end)

		it("contains TabLineFill highlight", function()
			assert.is_true(tabgroups.tabline():find("TabLineFill") ~= nil)
		end)

		it("contains right-align separator", function()
			local line = tabgroups.tabline()
			assert.is_true(line:find("%%=") ~= nil or line:find("%=") ~= nil)
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
end)
