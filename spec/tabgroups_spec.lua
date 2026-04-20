local tabgroups

describe("tabgroups", function()
	before_each(function()
		-- Reload to reset module-level state (group_names, group_vars tables)
		package.loaded["tabgroups"] = nil
		package.loaded["tabgroups.group_variables"] = nil
		tabgroups = require("tabgroups")
		-- Source the plugin to register autocmds (TabNew, TabEnter, etc.) and vim.tg
		vim.cmd("source plugin/tabgroups.lua")
		vim.g.tab_group_new_override = nil
	end)

	-- -------------------------------------------------------------------------
	-- tab group assignment
	-- -------------------------------------------------------------------------
	describe("tab group assignment", function()
		it("auto-assigns a gid on first use", function()
			tabgroups.tabline()
			local gid = tabgroups.get_tab_group(1)
			assert.is_true(type(gid) == "number" and gid > 0)
		end)

		it("assigned gid is stable across calls", function()
			tabgroups.tabline()
			local gid = tabgroups.get_tab_group(1)
			tabgroups.tabline()
			assert.are.same(gid, tabgroups.get_tab_group(1))
		end)
	end)

	-- -------------------------------------------------------------------------
	-- group names
	-- -------------------------------------------------------------------------
	describe("group names", function()
		it("unnamed group shows gid-based fallback name", function()
			local gid = tabgroups.get_tab_group(vim.fn.tabpagenr())
			assert.is_true(tabgroups.tabline():find("Tab Group " .. gid) ~= nil)
		end)

		it("renamed group shows explicit name instead of fallback", function()
			local gid = tabgroups.get_tab_group(vim.fn.tabpagenr())
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
			local gid = tabgroups.get_tab_group(1)
			vim.cmd("tabnew")  -- inherits current group via TabNew autocmd
			vim.cmd("tabnew")
			local _, count = tabgroups.tabline():gsub("Tab Group " .. gid, "")
			assert.are.same(1, count)
		end)

		it("shows a separate group entry for each distinct gid", function()
			local gid1 = tabgroups.get_tab_group(1)
			tabgroups.new_group("group2")
			local line = tabgroups.tabline()
			assert.is_true(line:find("Tab Group " .. gid1) ~= nil)
			assert.is_true(line:find("group2") ~= nil)
		end)

		it("groups appear ordered by their first tab", function()
			local gid_a = tabgroups.get_tab_group(1)
			tabgroups.new_group("B")  -- tab 2 in B
			vim.cmd("tabnext 1")      -- back to tab 1 (A)
			vim.cmd("tabnew")         -- inserts tab 2 in A; old tab 2 (B) → tab 3
			local line = tabgroups.tabline()
			assert.is_true(line:find("Tab Group " .. gid_a) < line:find(" B "))
		end)

		it("two groups show distinct entries in tabline", function()
			local gid1 = tabgroups.get_tab_group(1)
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
			-- Visit tab 3 last in group B so TabEnter sets _default_tab[B]=3
			tabgroups.new_group("B")    -- tab 2 (B)
			vim.cmd("tabnew")           -- tab 3 (B); TabEnter → _default_tab[B]=3
			vim.cmd("tabnext 1")        -- back to group A
			tabgroups.next_tab_group()
			assert.are.same(3, vim.fn.tabpagenr())
		end)

		it("prev_tab_group returns to last visited tab in group", function()
			-- Build tab1(A), tab2(A), tab3(B); visit tab2 last in A
			tabgroups.new_group("B")    -- tab 2 (B)
			vim.cmd("tabnext 1")        -- tab 1 (A); TabEnter → _default_tab[A]=1
			vim.cmd("tabnew")           -- new tab 2 (A); old B→tab 3; TabEnter → _default_tab[A]=2
			vim.cmd("tabnext 3")        -- group B
			tabgroups.prev_tab_group()
			assert.are.same(2, vim.fn.tabpagenr())
		end)

		it("next_tab_group falls back to first_tab when _default_tab was moved to another group", function()
			-- Build tab1(A), tab2(B), tab3(B); set _default_tab[B]=3 via navigation
			tabgroups.new_group("B")    -- tab 2 (B)
			vim.cmd("tabnew")           -- tab 3 (B); TabEnter → _default_tab[B]=3
			vim.cmd("tabnext 1")        -- tab 1 (A)
			vim.cmd("tabnext 3")        -- tab 3 (B); TabEnter → _default_tab[B]=3
			-- Move tab 3 into group A: _default_tab[B]=3 becomes stale
			local gid_a = tabgroups.get_tab_group(1)
			vim.ui.select = function(items, _, cb)
				for _, item in ipairs(items) do
					if item.gid == gid_a then cb(item); return end
				end
			end
			tabgroups.move_current_tab()   -- tab 3 → group A (no TabEnter fires)
			vim.cmd("tabnext 1")           -- tab 1 (A)
			tabgroups.next_tab_group()     -- B's _default_tab(3) is stale → falls back to first_tab=2
			assert.are.same(2, vim.fn.tabpagenr())
		end)
	end)
end)
