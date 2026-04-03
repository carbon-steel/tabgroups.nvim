local tabgroups = require("tabgroups")
local gv

describe("group_variables", function()
	before_each(function()
		-- Reload to reset module-level state (group_vars, proxies tables)
		package.loaded["tabgroups.group_variables"] = nil
		gv = require("tabgroups.group_variables")
		vim.tg = gv.make_proxy(function()
			return vim.fn.gettabvar(vim.fn.tabpagenr(), "tab_group_id")
		end)
		vim.fn.settabvar(vim.fn.tabpagenr(), "tab_group_id", 1)
	end)

	-- -------------------------------------------------------------------------
	-- Storage: get / set / clear
	-- -------------------------------------------------------------------------
	describe("storage", function()
		it("returns nil for unknown keys", function()
			assert.is_nil(gv.get(1, "missing"))
		end)

		it("stores and retrieves values", function()
			gv.set(1, "foo", "bar")
			assert.are.same("bar", gv.get(1, "foo"))
		end)

		it("groups have independent namespaces", function()
			gv.set(1, "x", "a")
			gv.set(2, "x", "b")
			assert.are.same("a", gv.get(1, "x"))
			assert.are.same("b", gv.get(2, "x"))
		end)

		it("clear wipes all keys for a group", function()
			gv.set(1, "foo", "a")
			gv.set(1, "bar", "b")
			gv.clear(1)
			assert.is_nil(gv.get(1, "foo"))
			assert.is_nil(gv.get(1, "bar"))
		end)

		it("clear does not affect sibling groups", function()
			gv.set(1, "x", "a")
			gv.set(2, "x", "b")
			gv.clear(1)
			assert.are.same("b", gv.get(2, "x"))
		end)
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
			vim.fn.settabvar(vim.fn.tabpagenr(), "tab_group_id", 1)
			vim.tg.x = "group 1"
			vim.fn.settabvar(vim.fn.tabpagenr(), "tab_group_id", 2)
			vim.tg.x = "group 2"
			vim.fn.settabvar(vim.fn.tabpagenr(), "tab_group_id", 1)
			assert.are.same("group 1", vim.tg.x)
			vim.fn.settabvar(vim.fn.tabpagenr(), "tab_group_id", 2)
			assert.are.same("group 2", vim.tg.x)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- vim.tg[gid]: addressed group access
	-- -------------------------------------------------------------------------
	describe("addressed group access (vim.tg[gid])", function()
		after_each(function()
			while vim.fn.tabpagenr("$") > 1 do
				vim.cmd("tabclose $")
			end
		end)

		it("reads from the addressed group", function()
			local gid =
				tabgroups._get_tab_group(vim.api.nvim_tabpage_get_number(0))
			vim.tg.lang = "lua"
			tabgroups.new_group("hello")
			assert.are.same("lua", vim.tg[gid].lang)
			assert.is_nil(vim.tg.lang)
		end)

		it("writes to the addressed group", function()
			local gid =
				tabgroups._get_tab_group(vim.api.nvim_tabpage_get_number(0))
			tabgroups.new_group("hello")
			vim.tg[gid].lang = "lua"
			assert.are.same("lua", gv.get(gid, "lang"))
		end)

		it("addressed groups are independent", function()
			local gid1 =
				tabgroups._get_tab_group(vim.api.nvim_tabpage_get_number(0))
			tabgroups.new_group("hello")
			local gid2 =
				tabgroups._get_tab_group(vim.api.nvim_tabpage_get_number(0))
			vim.tg[gid1].val = "ten"
			vim.tg[gid2].val = "twenty"
			assert.are.same("ten", vim.tg[gid1].val)
			assert.are.same("twenty", vim.tg[gid2].val)
		end)

		it("returns the same proxy table on repeated access", function()
			local gid =
				tabgroups._get_tab_group(vim.api.nvim_tabpage_get_number(0))
			assert.are.equal(vim.tg[gid], vim.tg[gid])
		end)

		it("does not write to the current group", function()
			local gid =
				tabgroups._get_tab_group(vim.api.nvim_tabpage_get_number(0))
			tabgroups.new_group("hello")
			vim.tg[gid].x = "three"
			assert.is_nil(vim.tg.x)
		end)

		it("returns fresh state after clear", function()
			local gid =
				tabgroups._get_tab_group(vim.api.nvim_tabpage_get_number(0))
			vim.tg[gid].key = "before"
			gv.clear(gid)
			assert.is_nil(vim.tg[gid].key)
		end)
	end)
end)
