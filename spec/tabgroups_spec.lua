local tabgroups

describe("tabgroups", function()
	before_each(function()
		-- Reload to reset module-level state (group_names, group_vars tables)
		package.loaded["tabgroups"] = nil
		package.loaded["tabgroups.group_variables"] = nil
		tabgroups = require("tabgroups")
		local gv = require("tabgroups.group_variables")
		vim.tg = gv.make_proxy(function()
			return vim.fn.gettabvar(vim.fn.tabpagenr(), "tab_group_id")
		end)
		vim.g.tab_group_counter = 0
		vim.g.tab_group_new_override = nil
		for tabnr = 1, vim.fn.tabpagenr("$") do
			vim.fn.settabvar(tabnr, "tab_group_id", "")
		end
	end)

	-- -------------------------------------------------------------------------
	-- tab group assignment
	-- -------------------------------------------------------------------------
	describe("tab group assignment", function()
		it("auto-assigns a gid on first use", function()
			-- tabline triggers get_tab_group which auto-assigns
			tabgroups.tabline()
			local gid = vim.fn.gettabvar(1, "tab_group_id")
			assert.is_true(type(gid) == "number" and gid > 0)
		end)

		it("preserves an explicitly set gid", function()
			vim.fn.settabvar(1, "tab_group_id", 42)
			assert.are.same(42, vim.fn.gettabvar(1, "tab_group_id"))
		end)
	end)

	-- -------------------------------------------------------------------------
	-- group names
	-- -------------------------------------------------------------------------
	describe("group names", function()
		it("unnamed group shows gid-based fallback name", function()
			vim.fn.settabvar(1, "tab_group_id", 7)
			assert.is_true(tabgroups.tabline():find("Tab Group 7") ~= nil)
		end)

		it("renamed group shows explicit name instead of fallback", function()
			vim.fn.settabvar(1, "tab_group_id", 1)
			tabgroups.rename_current_group("frontend")
			local line = tabgroups.tabline()
			assert.is_true(line:find("frontend") ~= nil)
			assert.is_nil(line:find("Tab Group 1"))
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
			vim.cmd("tabnew")
			vim.cmd("tabnew")
			vim.fn.settabvar(1, "tab_group_id", 1)
			vim.fn.settabvar(2, "tab_group_id", 1)
			vim.fn.settabvar(3, "tab_group_id", 1)
			local _, count = tabgroups.tabline():gsub("Tab Group 1", "")
			assert.are.same(1, count)
		end)

		it("shows a separate group entry for each distinct gid", function()
			vim.cmd("tabnew")
			vim.fn.settabvar(1, "tab_group_id", 10)
			vim.fn.settabvar(2, "tab_group_id", 20)
			local line = tabgroups.tabline()
			assert.is_true(line:find("Tab Group 10") ~= nil)
			assert.is_true(line:find("Tab Group 20") ~= nil)
		end)

		it("groups appear ordered by their first tab", function()
			vim.cmd("tabnew")
			vim.cmd("tabnew")
			-- tab 1 → A, tab 2 → B, tab 3 → A: A's first tab is 1, B's is 2
			vim.fn.settabvar(1, "tab_group_id", 100)
			vim.fn.settabvar(2, "tab_group_id", 200)
			vim.fn.settabvar(3, "tab_group_id", 100)
			local line = tabgroups.tabline()
			assert.is_true(line:find("Tab Group 100") < line:find("Tab Group 200"))
		end)

		it("two unnamed groups get distinct names", function()
			vim.cmd("tabnew")
			vim.fn.settabvar(1, "tab_group_id", 5)
			vim.fn.settabvar(2, "tab_group_id", 6)
			local line = tabgroups.tabline()
			assert.is_true(line:find("Tab Group 5") ~= nil)
			assert.is_true(line:find("Tab Group 6") ~= nil)
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

		it("next_tab_group jumps to _default_tab when set and valid", function()
			-- tab 1 → group 1, tabs 2+3 → group 2; _default_tab for group 2 is tab 3
			vim.cmd("tabnew")
			vim.cmd("tabnew")
			vim.fn.settabvar(1, "tab_group_id", 1)
			vim.fn.settabvar(2, "tab_group_id", 2)
			vim.fn.settabvar(3, "tab_group_id", 2)
			vim.tg[2]._default_tab = 3
			vim.cmd("tabnext 1")
			tabgroups.next_tab_group()
			assert.are.same(3, vim.fn.tabpagenr())
		end)

		it("next_tab_group falls back to first_tab when _default_tab not set", function()
			vim.cmd("tabnew")
			vim.cmd("tabnew")
			vim.fn.settabvar(1, "tab_group_id", 1)
			vim.fn.settabvar(2, "tab_group_id", 2)
			vim.fn.settabvar(3, "tab_group_id", 2)
			vim.cmd("tabnext 1")
			tabgroups.next_tab_group()
			assert.are.same(2, vim.fn.tabpagenr())
		end)

		it("next_tab_group falls back to first_tab when _default_tab is stale", function()
			-- _default_tab points to a tab that now belongs to a different group
			vim.cmd("tabnew")
			vim.cmd("tabnew")
			vim.fn.settabvar(1, "tab_group_id", 1)
			vim.fn.settabvar(2, "tab_group_id", 2)
			vim.fn.settabvar(3, "tab_group_id", 2)
			-- tab 2 is in group 2, so setting _default_tab for group 2 to tab 1 is stale
			vim.tg[2]._default_tab = 1
			vim.cmd("tabnext 1")
			tabgroups.next_tab_group()
			assert.are.same(2, vim.fn.tabpagenr())
		end)

		it("prev_tab_group jumps to _default_tab when set and valid", function()
			-- tabs 1+2 → group 1, tab 3 → group 2; _default_tab for group 1 is tab 2
			vim.cmd("tabnew")
			vim.cmd("tabnew")
			vim.fn.settabvar(1, "tab_group_id", 1)
			vim.fn.settabvar(2, "tab_group_id", 1)
			vim.fn.settabvar(3, "tab_group_id", 2)
			vim.tg[1]._default_tab = 2
			vim.cmd("tabnext 3")
			tabgroups.prev_tab_group()
			assert.are.same(2, vim.fn.tabpagenr())
		end)

		it("prev_tab_group falls back to first_tab when _default_tab not set", function()
			vim.cmd("tabnew")
			vim.cmd("tabnew")
			vim.fn.settabvar(1, "tab_group_id", 1)
			vim.fn.settabvar(2, "tab_group_id", 1)
			vim.fn.settabvar(3, "tab_group_id", 2)
			vim.cmd("tabnext 3")
			tabgroups.prev_tab_group()
			assert.are.same(1, vim.fn.tabpagenr())
		end)
	end)
end)
