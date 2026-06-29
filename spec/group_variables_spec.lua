local tabgroups

describe("group_variables", function()
	before_each(function()
		-- Reload to reset module-level state (group_vars, proxies tables)
		for name in pairs(package.loaded) do
			if vim.startswith(name, "tabgroups") then
				package.loaded[name] = nil
			end
		end
		tabgroups = require("tabgroups")
		vim.cmd("source plugin/tabgroups.lua")
		-- Ensure the initial tab has tabgroup_id set before any tg access
		tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
	end)

	after_each(function()
		while vim.fn.tabpagenr("$") > 1 do
			vim.cmd("tabclose $")
		end
	end)

	-- -------------------------------------------------------------------------
	-- tabgroups.tg.key: current group access
	-- -------------------------------------------------------------------------
	describe("current group access (tabgroups.tg.key)", function()
		it("writes to and reads from the current group", function()
			tabgroups.tg.foo = "bar"
			assert.are.same("bar", tabgroups.tg.foo)
		end)

		it("returns nil for unset keys", function()
			assert.is_nil(tabgroups.tg.missing)
		end)

		it("dispatches to whichever group is current at access time", function()
			local tab1 = vim.api.nvim_get_current_tabpage()
			tabgroups.new_group("other")
			local tab2 = vim.api.nvim_get_current_tabpage()
			vim.api.nvim_set_current_tabpage(tab1)
			tabgroups.tg.x = "group 1"
			vim.api.nvim_set_current_tabpage(tab2)
			tabgroups.tg.x = "group 2"
			vim.api.nvim_set_current_tabpage(tab1)
			assert.are.same("group 1", tabgroups.tg.x)
			vim.api.nvim_set_current_tabpage(tab2)
			assert.are.same("group 2", tabgroups.tg.x)
			vim.api.nvim_win_close(0, true)
			assert.are.same("group 1", tabgroups.tg.x)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- tabgroups.tg[gid]: addressed group access
	-- -------------------------------------------------------------------------
	describe("addressed group access (tabgroups.tg[gid])", function()
		it("reads from the addressed group", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			tabgroups.tg.lang = "lua"
			tabgroups.new_group("hello")
			assert.are.same("lua", tabgroups.tg[gid].lang)
			assert.is_nil(tabgroups.tg.lang)
		end)

		it("writes to the addressed group", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			tabgroups.new_group("hello")
			tabgroups.tg[gid].lang = "lua"
			assert.are.same("lua", tabgroups.tg[gid].lang)
		end)

		it("addressed groups are independent", function()
			local gid1 =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			tabgroups.new_group("hello")
			local gid2 =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			tabgroups.tg[gid1].val = "ten"
			tabgroups.tg[gid2].val = "twenty"
			assert.are.same("ten", tabgroups.tg[gid1].val)
			assert.are.same("twenty", tabgroups.tg[gid2].val)
		end)

		it("returns the same proxy table on repeated access", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			assert.are.equal(tabgroups.tg[gid], tabgroups.tg[gid])
		end)

		it("does not write to the current group", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			tabgroups.new_group("hello")
			tabgroups.tg[gid].x = "three"
			assert.is_nil(tabgroups.tg.x)
		end)

		it("returns fresh state after clear", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			tabgroups.tg[gid].key = "before"
			require("tabgroups.state").group_clear(gid)
			assert.is_nil(tabgroups.tg[gid].key)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- key validation
	-- -------------------------------------------------------------------------
	describe("key validation", function()
		it("rejects a numeric string key on tg write", function()
			assert.has_error(function()
				tabgroups.tg["1"] = "val"
			end)
		end)

		it("rejects a numeric string key on tg read", function()
			assert.has_error(function()
				return tabgroups.tg["1"]
			end)
		end)

		it("rejects a bare number key on tg write", function()
			assert.has_error(function()
				tabgroups.tg[99] = "val"
			end)
		end)

		it("rejects a float string key on tg write", function()
			assert.has_error(function()
				tabgroups.tg["1.5"] = "val"
			end)
		end)

		it("rejects a numeric string key on addressed group write", function()
			local gid = tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			assert.has_error(function()
				tabgroups.tg[gid]["1"] = "val"
			end)
		end)

		it("rejects a numeric string key on addressed group read", function()
			local gid = tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			assert.has_error(function()
				return tabgroups.tg[gid]["1"]
			end)
		end)

		it("rejects a bare number key on addressed group write", function()
			local gid = tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			assert.has_error(function()
				tabgroups.tg[gid][99] = "val"
			end)
		end)

		it("rejects a bare number key on addressed group read", function()
			local gid = tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			assert.has_error(function()
				return tabgroups.tg[gid][99]
			end)
		end)

		it("accepts a plain string key", function()
			assert.has_no.errors(function()
				tabgroups.tg.foo = "bar"
				return tabgroups.tg.foo
			end)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- variable correctness after tab group switching
	-- -------------------------------------------------------------------------
	describe("variable correctness after tab group switching", function()
		after_each(function()
			while vim.fn.tabpagenr("$") > 1 do
				vim.cmd("tabclose $")
			end
		end)

		it("tg reads the correct group after next_tab_group", function()
			tabgroups.tg.val = "group_a"
			tabgroups.new_group("B")
			tabgroups.tg.val = "group_b"
			tabgroups.prev_tab_group() -- back to A
			assert.are.same("group_a", tabgroups.tg.val)
			tabgroups.next_tab_group() -- forward to B
			assert.are.same("group_b", tabgroups.tg.val)
			tabgroups.next_tab_group() -- forward to A
			assert.are.same("group_a", tabgroups.tg.val)
		end)

		it(
			"writes after next_tab_group land in the destination group",
			function()
				local gid_a =
					tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
				tabgroups.new_group("B")
				local gid_b =
					tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
				tabgroups.prev_tab_group() -- back to A
				tabgroups.next_tab_group() -- forward to B
				tabgroups.tg.written = "in_b"
				tabgroups.prev_tab_group() -- back to A
				assert.are.same("in_b", tabgroups.tg[gid_b].written)
				assert.is_nil(tabgroups.tg[gid_a].written)
			end
		)

		it("original group variables survive a next/prev round-trip", function()
			tabgroups.tg.x = "start"
			tabgroups.new_group("B")
			-- currently in B; prev→A, next→B, prev→A
			tabgroups.prev_tab_group() -- B → A
			tabgroups.next_tab_group() -- A → B
			tabgroups.prev_tab_group() -- B → A
			assert.are.same("start", tabgroups.tg.x)
		end)

		it(
			"all groups keep distinct values across multiple switches",
			function()
				local tab_a = vim.api.nvim_get_current_tabpage()
				local gid_a = tabgroups.get_tab_group(tab_a)
				tabgroups.tg.color = "red"
				tabgroups.new_group("B")
				local gid_b =
					tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
				tabgroups.tg.color = "blue"
				tabgroups.new_group("C")
				local gid_c =
					tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
				tabgroups.tg.color = "green"

				-- switch around and verify no cross-contamination
				tabgroups.prev_tab_group() -- C → B
				assert.are.same("blue", tabgroups.tg.color)
				tabgroups.prev_tab_group() -- B → A
				assert.are.same("red", tabgroups.tg.color)
				tabgroups.next_tab_group() -- A → B
				assert.are.same("blue", tabgroups.tg.color)
				tabgroups.next_tab_group() -- B → C
				assert.are.same("green", tabgroups.tg.color)

				-- addressed access stays independent throughout
				assert.are.same("red", tabgroups.tg[gid_a].color)
				assert.are.same("blue", tabgroups.tg[gid_b].color)
				assert.are.same("green", tabgroups.tg[gid_c].color)
			end
		)

		it(
			"tg.clear in one group does not affect variables in another group after switching",
			function()
				tabgroups.tg.k = "a"
				tabgroups.new_group("B")
				tabgroups.tg.k = "b"
				local gid_b =
					tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
				require("tabgroups.state").group_clear(gid_b)
				tabgroups.prev_tab_group() -- back to A
				assert.are.same("a", tabgroups.tg.k)
				tabgroups.prev_tab_group() -- to B
				assert.is_nil(tabgroups.tg.k)
			end
		)
	end)

end)
