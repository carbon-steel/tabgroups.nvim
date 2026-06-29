local tabgroups

describe("session persistence", function()
	local tmpfile

	before_each(function()
		for name in pairs(package.loaded) do
			if vim.startswith(name, "tabgroups") then
				package.loaded[name] = nil
			end
		end
		tabgroups = require("tabgroups")
		vim.cmd("source plugin/tabgroups.lua")
		tmpfile = vim.fn.tempname() .. ".vim"
	end)

	after_each(function()
		while vim.fn.tabpagenr("$") > 1 do
			vim.cmd("tabclose $")
		end
		vim.fn.delete(tmpfile)
	end)

	-- -------------------------------------------------------------------------
	-- tab state: tab-to-group associations are saved and restored across sessions
	-- -------------------------------------------------------------------------
	describe("tab state", function()
		it("restores the group ID for a tab", function()
			local handle = vim.api.nvim_get_current_tabpage()
			local gid = tabgroups.get_tab_group(handle)
			vim.cmd("mksession! " .. tmpfile)

			for name in pairs(package.loaded) do
				if vim.startswith(name, "tabgroups") then
					package.loaded[name] = nil
				end
			end
			tabgroups = require("tabgroups")
			vim.cmd("source plugin/tabgroups.lua")
			vim.cmd("source " .. tmpfile)

			assert.are.same(gid, tabgroups.get_tab_group(handle))
		end)

		it("restores group IDs across multiple tabs to the correct tabs", function()
			local handle1 = vim.api.nvim_get_current_tabpage()
			local gid1 = tabgroups.get_tab_group(handle1)
			tabgroups.new_group("B")
			local handle2 = vim.api.nvim_get_current_tabpage()
			local gid2 = tabgroups.get_tab_group(handle2)
			vim.cmd("mksession! " .. tmpfile)

			for name in pairs(package.loaded) do
				if vim.startswith(name, "tabgroups") then
					package.loaded[name] = nil
				end
			end
			tabgroups = require("tabgroups")
			vim.cmd("source plugin/tabgroups.lua")
			vim.cmd("source " .. tmpfile)

			local pages = vim.api.nvim_list_tabpages()
			assert.are.same(gid1, tabgroups.get_tab_group(pages[1]))
			assert.are.same(gid2, tabgroups.get_tab_group(pages[2]))
		end)

		it(
			"get_tab_group returns the restored gid after module reload",
			function()
				local gid =
					tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
				vim.cmd("mksession! " .. tmpfile)

				for name in pairs(package.loaded) do
					if vim.startswith(name, "tabgroups") then
						package.loaded[name] = nil
					end
				end
				tabgroups = require("tabgroups")
				vim.cmd("source plugin/tabgroups.lua")
				vim.cmd("source " .. tmpfile)

				assert.are.same(
					gid,
					tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
				)
			end
		)

		it("restores default_tab to the correct handle after module reload", function()
			local state = require("tabgroups.state")
			-- Create two tabs in the same group; TabEnter sets default_tab to the last-entered tab
			local tab1 = vim.api.nvim_get_current_tabpage()
			local gid = tabgroups.get_tab_group(tab1)
			vim.cmd("tabnew")
			local tab2 = vim.api.nvim_get_current_tabpage()
			-- tab2 is now the default_tab for gid
			assert.are.same(tab2, state.group_get(gid, state.GROUP.DEFAULT_TAB))
			vim.cmd("mksession! " .. tmpfile)

			for name in pairs(package.loaded) do
				if vim.startswith(name, "tabgroups") then
					package.loaded[name] = nil
				end
			end
			tabgroups = require("tabgroups")
			state = require("tabgroups.state")
			vim.cmd("source plugin/tabgroups.lua")
			vim.cmd("source " .. tmpfile)

			local pages = vim.api.nvim_list_tabpages()
			assert.are.same(pages[2], state.group_get(gid, state.GROUP.DEFAULT_TAB))
		end)

		it(
			"new group ids are greater than any id from the restored session",
			function()
				local gid1 =
					tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
				tabgroups.new_group("B")
				local gid2 =
					tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
				assert.is_true(gid2 > gid1)
				vim.cmd("mksession! " .. tmpfile)

				for name in pairs(package.loaded) do
					if vim.startswith(name, "tabgroups") then
						package.loaded[name] = nil
					end
				end
				tabgroups = require("tabgroups")
				vim.cmd("source plugin/tabgroups.lua")
				vim.cmd("source " .. tmpfile)

				tabgroups.new_group("C")
				local gid3 =
					tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())

				assert.is_true(gid3 > gid2)
			end
		)
	end)

	-- -------------------------------------------------------------------------
	-- state.group: group-scoped plugin state is saved and restored
	-- -------------------------------------------------------------------------
	describe("state.group", function()
		local state

		before_each(function()
			state = require("tabgroups.state")
		end)

		it("restores a string field", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			state.group_set(gid, "mode", "dark")
			vim.cmd("mksession! " .. tmpfile)

			for name in pairs(package.loaded) do
				if vim.startswith(name, "tabgroups") then
					package.loaded[name] = nil
				end
			end
			tabgroups = require("tabgroups")
			state = require("tabgroups.state")
			vim.cmd("source plugin/tabgroups.lua")
			vim.cmd("source " .. tmpfile)

			assert.are.same("dark", state.group_get(gid, "mode"))
		end)

		it("restores a numeric field", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			state.group_set(gid, "count", 42)
			vim.cmd("mksession! " .. tmpfile)

			for name in pairs(package.loaded) do
				if vim.startswith(name, "tabgroups") then
					package.loaded[name] = nil
				end
			end
			tabgroups = require("tabgroups")
			state = require("tabgroups.state")
			vim.cmd("source plugin/tabgroups.lua")
			vim.cmd("source " .. tmpfile)

			assert.are.same(42, state.group_get(gid, "count"))
		end)

		it("restores multiple groups independently", function()
			local gid1 =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			state.group_set(gid1, "color", "red")
			tabgroups.new_group("B")
			local gid2 =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			state.group_set(gid2, "color", "blue")
			vim.cmd("mksession! " .. tmpfile)

			for name in pairs(package.loaded) do
				if vim.startswith(name, "tabgroups") then
					package.loaded[name] = nil
				end
			end
			tabgroups = require("tabgroups")
			state = require("tabgroups.state")
			vim.cmd("source plugin/tabgroups.lua")
			vim.cmd("source " .. tmpfile)

			assert.are.same("red", state.group_get(gid1, "color"))
			assert.are.same("blue", state.group_get(gid2, "color"))
		end)
	end)

	-- -------------------------------------------------------------------------
	-- state.global: global-scoped plugin state is saved and restored
	-- -------------------------------------------------------------------------
	describe("state.global", function()
		local state

		before_each(function()
			state = require("tabgroups.state")
		end)

		it("restores a string field", function()
			state.global_set("theme", "dark")
			vim.cmd("mksession! " .. tmpfile)

			for name in pairs(package.loaded) do
				if vim.startswith(name, "tabgroups") then
					package.loaded[name] = nil
				end
			end
			tabgroups = require("tabgroups")
			state = require("tabgroups.state")
			vim.cmd("source plugin/tabgroups.lua")
			vim.cmd("source " .. tmpfile)

			assert.are.same("dark", state.global_get("theme"))
		end)

		it("restores a numeric field", function()
			state.global_set("count", 7)
			vim.cmd("mksession! " .. tmpfile)

			for name in pairs(package.loaded) do
				if vim.startswith(name, "tabgroups") then
					package.loaded[name] = nil
				end
			end
			tabgroups = require("tabgroups")
			state = require("tabgroups.state")
			vim.cmd("source plugin/tabgroups.lua")
			vim.cmd("source " .. tmpfile)

			assert.are.same(7, state.global_get("count"))
		end)

		it("restores multiple fields independently", function()
			state.global_set("a", "alpha")
			state.global_set("b", 2)
			vim.cmd("mksession! " .. tmpfile)

			for name in pairs(package.loaded) do
				if vim.startswith(name, "tabgroups") then
					package.loaded[name] = nil
				end
			end
			tabgroups = require("tabgroups")
			state = require("tabgroups.state")
			vim.cmd("source plugin/tabgroups.lua")
			vim.cmd("source " .. tmpfile)

			assert.are.same("alpha", state.global_get("a"))
			assert.are.same(2, state.global_get("b"))
		end)
	end)

	-- -------------------------------------------------------------------------
	-- group_vars: in-memory tg state is saved and restored across sessions
	-- -------------------------------------------------------------------------
	describe("group_vars", function()
		it("restores a string value after clear", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			tabgroups.tg.key = "hello"
			vim.cmd("mksession! " .. tmpfile)
			require("tabgroups.state").group_clear(gid)
			vim.cmd("source " .. tmpfile)
			assert.are.same("hello", tabgroups.tg.key)
		end)

		it("restores a numeric value after clear", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			tabgroups.tg.count = 99
			vim.cmd("mksession! " .. tmpfile)
			require("tabgroups.state").group_clear(gid)
			vim.cmd("source " .. tmpfile)
			assert.are.same(99, tabgroups.tg.count)
		end)

		it("restores a table value after clear", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			tabgroups.tg.opts = { x = 1, y = 2 }
			vim.cmd("mksession! " .. tmpfile)
			require("tabgroups.state").group_clear(gid)
			vim.cmd("source " .. tmpfile)
			assert.are.same({ x = 1, y = 2 }, tabgroups.tg.opts)
		end)

		it("restores multiple keys in one group", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			tabgroups.tg.a = "alpha"
			tabgroups.tg.b = 2
			tabgroups.tg.c = true
			vim.cmd("mksession! " .. tmpfile)
			require("tabgroups.state").group_clear(gid)
			vim.cmd("source " .. tmpfile)
			assert.are.same("alpha", tabgroups.tg.a)
			assert.are.same(2, tabgroups.tg.b)
			assert.are.same(true, tabgroups.tg.c)
		end)

		it("restores multiple groups independently", function()
			local gid1 =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			tabgroups.tg.color = "red"
			tabgroups.new_group("B")
			local gid2 =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			tabgroups.tg.color = "blue"
			vim.cmd("mksession! " .. tmpfile)
			require("tabgroups.state").group_clear(gid1)
			require("tabgroups.state").group_clear(gid2)
			vim.cmd("source " .. tmpfile)
			assert.are.same("red", tabgroups.tg[gid1].color)
			assert.are.same("blue", tabgroups.tg[gid2].color)
		end)

		it(
			"after module reload, sourcing the session restores group_vars",
			function()
				local gid =
					tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
				tabgroups.tg.key = "restored"
				vim.cmd("mksession! " .. tmpfile)

				for name in pairs(package.loaded) do
					if vim.startswith(name, "tabgroups") then
						package.loaded[name] = nil
					end
				end
				tabgroups = require("tabgroups")
				vim.cmd("source plugin/tabgroups.lua")

				vim.cmd("source " .. tmpfile)

				assert.are.same("restored", tabgroups.tg[gid].key)
			end
		)
	end)
end)
