local tabgroups

describe("group_variables", function()
	before_each(function()
		-- Reload to reset module-level state (group_vars, proxies tables)
		package.loaded["tabgroups"] = nil
		package.loaded["tabgroups.group_variables"] = nil
		package.loaded["tabgroups.internal"] = nil
		tabgroups = require("tabgroups")
		vim.cmd("source plugin/tabgroups.lua")
	end)

	after_each(function()
		while vim.fn.tabpagenr("$") > 1 do
			vim.cmd("tabclose $")
		end
	end)

	-- -------------------------------------------------------------------------
	-- vim.tg.key: current group access
	-- -------------------------------------------------------------------------
	describe("current group access (vim.tg.key)", function()
		it("writes to and reads from the current group", function()
			vim.tg.foo = "bar"
			assert.are.same("bar", vim.tg.foo)
		end)

		it("returns nil for unset keys", function()
			assert.is_nil(vim.tg.missing)
		end)

		it("dispatches to whichever group is current at access time", function()
			local tab1 = vim.api.nvim_get_current_tabpage()
			tabgroups.new_group("other")
			local tab2 = vim.api.nvim_get_current_tabpage()
			vim.api.nvim_set_current_tabpage(tab1)
			vim.tg.x = "group 1"
			vim.api.nvim_set_current_tabpage(tab2)
			vim.tg.x = "group 2"
			vim.api.nvim_set_current_tabpage(tab1)
			assert.are.same("group 1", vim.tg.x)
			vim.api.nvim_set_current_tabpage(tab2)
			assert.are.same("group 2", vim.tg.x)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- vim.tg[gid]: addressed group access
	-- -------------------------------------------------------------------------
	describe("addressed group access (vim.tg[gid])", function()
		it("reads from the addressed group", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			vim.tg.lang = "lua"
			tabgroups.new_group("hello")
			assert.are.same("lua", vim.tg[gid].lang)
			assert.is_nil(vim.tg.lang)
		end)

		it("writes to the addressed group", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			tabgroups.new_group("hello")
			vim.tg[gid].lang = "lua"
			assert.are.same("lua", vim.tg[gid].lang)
		end)

		it("addressed groups are independent", function()
			local gid1 =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			tabgroups.new_group("hello")
			local gid2 =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			vim.tg[gid1].val = "ten"
			vim.tg[gid2].val = "twenty"
			assert.are.same("ten", vim.tg[gid1].val)
			assert.are.same("twenty", vim.tg[gid2].val)
		end)

		it("returns the same proxy table on repeated access", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			assert.are.equal(vim.tg[gid], vim.tg[gid])
		end)

		it("does not write to the current group", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			tabgroups.new_group("hello")
			vim.tg[gid].x = "three"
			assert.is_nil(vim.tg.x)
		end)

		it("returns fresh state after clear", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			vim.tg[gid].key = "before"
			vim.tg.clear(gid)
			assert.is_nil(vim.tg[gid].key)
		end)
	end)
end)
