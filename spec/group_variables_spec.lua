local tabgroups

describe("group_variables", function()
	before_each(function()
		-- Reload to reset module-level state (group_vars, proxies tables)
		package.loaded["tabgroups"] = nil
		package.loaded["tabgroups.group_variables"] = nil
		package.loaded["tabgroups.internal"] = nil
		package.loaded["tabgroups.setup"] = nil
		tabgroups = require("tabgroups")
		vim.cmd("source plugin/tabgroups.lua")
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
			tabgroups.tg.clear(gid)
			assert.is_nil(tabgroups.tg[gid].key)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- save_group_vars / load_group_vars: persist and restore variables
	-- -------------------------------------------------------------------------
	describe("save_group_vars / load_group_vars", function()
		local tmpfile

		before_each(function()
			tmpfile = vim.fn.tempname() .. ".json"
		end)

		after_each(function()
			vim.fn.delete(tmpfile)
		end)

		it(
			"restores variables to the current group after save and clear",
			function()
				tabgroups.tg.key1 = "val1"
				tabgroups.tg.key2 = 42
				tabgroups.tg.key3 = true
				tabgroups.tg.key4 = { "a", "b", "c" }
				tabgroups.tg.key5 = { x = 1, y = 2 }
				local gid =
					tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
				assert.is_true(tabgroups.save_group_vars(tmpfile, gid))
				tabgroups.tg.clear(gid)
				assert.is_true(tabgroups.load_group_vars(tmpfile, gid))
				assert.are.same("val1", tabgroups.tg.key1)
				assert.are.same(42, tabgroups.tg.key2)
				assert.are.same(true, tabgroups.tg.key3)
				assert.are.same({ "a", "b", "c" }, tabgroups.tg.key4)
				assert.are.same({ x = 1, y = 2 }, tabgroups.tg.key5)
			end
		)

		it(
			"save defaults to current group; load restores the same variables",
			function()
				tabgroups.tg.project = "myproject"
				local gid =
					tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
				assert.is_true(tabgroups.save_group_vars(tmpfile))
				tabgroups.tg.clear(gid)
				assert.is_true(tabgroups.load_group_vars(tmpfile))
				assert.are.same("myproject", tabgroups.tg.project)
			end
		)

		it(
			"with a conflict handler, the handler resolves key conflicts",
			function()
				local gid =
					tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
				tabgroups.tg.key = "from_file"
				assert.is_true(tabgroups.save_group_vars(tmpfile, gid))
				tabgroups.tg.key = "existing"
				assert.is_true(
					tabgroups.load_group_vars(
						tmpfile,
						gid,
						function(_, existing, _)
							return existing
						end
					)
				)
				assert.are.same("existing", tabgroups.tg.key)
			end
		)

		it(
			"conflict handler returning the incoming value overwrites the existing one",
			function()
				local gid =
					tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
				tabgroups.tg.key = "from_file"
				assert.is_true(tabgroups.save_group_vars(tmpfile, gid))
				tabgroups.tg.key = "existing"
				assert.is_true(
					tabgroups.load_group_vars(
						tmpfile,
						gid,
						function(_, _, incoming)
							return incoming
						end
					)
				)
				assert.are.same("from_file", tabgroups.tg.key)
			end
		)

		it("conflict handler can combine numeric values", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			tabgroups.tg.count = 3
			assert.is_true(tabgroups.save_group_vars(tmpfile, gid))
			tabgroups.tg.count = 10
			assert.is_true(
				tabgroups.load_group_vars(
					tmpfile,
					gid,
					function(_, existing, incoming)
						return existing + incoming
					end
				)
			)
			assert.are.same(13, tabgroups.tg.count)
		end)

		it("conflict handler receives the correct key name", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			tabgroups.tg.alpha = 1
			tabgroups.tg.beta = 2
			assert.is_true(tabgroups.save_group_vars(tmpfile, gid))
			local seen_keys = {}
			assert.is_true(
				tabgroups.load_group_vars(
					tmpfile,
					gid,
					function(key, existing, _)
						seen_keys[key] = existing
						return existing
					end
				)
			)
			assert.are.same(1, seen_keys.alpha)
			assert.are.same(2, seen_keys.beta)
		end)

		it(
			"conflict handler is not called for keys only in the file",
			function()
				local gid =
					tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
				tabgroups.tg.file_only = "yes"
				assert.is_true(tabgroups.save_group_vars(tmpfile, gid))
				tabgroups.tg.clear(gid)
				local handler_called = false
				assert.is_true(
					tabgroups.load_group_vars(
						tmpfile,
						gid,
						function(_, existing, incoming)
							handler_called = true
							return incoming
						end
					)
				)
				assert.is_false(handler_called)
				assert.are.same("yes", tabgroups.tg.file_only)
			end
		)

		it(
			"saves and restores variables for a non-current group by gid",
			function()
				local gid1 =
					tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
				tabgroups.tg.project = "group1"
				tabgroups.new_group("other")
				tabgroups.tg.project = "group2"
				assert.is_true(tabgroups.save_group_vars(tmpfile, gid1))
				tabgroups.tg.clear(gid1)
				assert.is_true(tabgroups.load_group_vars(tmpfile, gid1))
				assert.are.same("group1", tabgroups.tg[gid1].project)
				assert.are.same("group2", tabgroups.tg.project)
			end
		)

		it("load replaces existing variables with saved ones", function()
			local gid =
				tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
			tabgroups.tg.key = "saved"
			assert.is_true(tabgroups.save_group_vars(tmpfile, gid))
			tabgroups.tg.key = "overwritten"
			assert.is_true(tabgroups.load_group_vars(tmpfile, gid))
			assert.are.same("saved", tabgroups.tg.key)
		end)

		it(
			"load does not clear variables not present in the saved file",
			function()
				local gid1 =
					tabgroups.get_tab_group(vim.api.nvim_get_current_tabpage())
				tabgroups.tg.unrelated = "yes"
				-- Save a different group that has only "kept"
				tabgroups.new_group("source")
				tabgroups.tg.kept = "yes"
				assert.is_true(tabgroups.save_group_vars(tmpfile))
				-- Load it into gid1, which has "unrelated" but not "kept"
				assert.is_true(tabgroups.load_group_vars(tmpfile, gid1))
				assert.are.same("yes", tabgroups.tg[gid1].unrelated)
				assert.are.same("yes", tabgroups.tg[gid1].kept)
			end
		)

		it("load returns false for a missing file", function()
			local ok = tabgroups.load_group_vars("/nonexistent/path.json")
			assert.is_false(ok)
		end)

		it("load returns false for invalid JSON", function()
			vim.fn.writefile({ "not json" }, tmpfile)
			local ok = tabgroups.load_group_vars(tmpfile)
			assert.is_false(ok)
		end)
	end)
end)
