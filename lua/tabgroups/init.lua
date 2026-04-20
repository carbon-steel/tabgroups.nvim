-- tabgroups.nvim: organize neovim tabs into named groups
local M = {}

-- Group names: gid -> name (module-level, lives as long as nvim session)
local group_names = {}

local function get_group_name(gid)
	return group_names[gid]
end

local function set_group_name(gid, name)
	group_names[gid] = name
end

-- Generate a unique group ID using a global counter (persists across reloads)
local function new_group_id()
	local id = (vim.g.tab_group_counter or 0) + 1
	vim.g.tab_group_counter = id
	return id
end

-- Get group ID for a tab (auto-assigns one if not set)
local function get_tab_group(tabnr)
	local gid = vim.fn.gettabvar(tabnr, "tab_group_id", "")
	if gid == "" then
		gid = new_group_id()
		vim.fn.settabvar(tabnr, "tab_group_id", gid)
	end
	return gid
end

-- Set group ID for a tab
local function set_tab_group(tabnr, gid)
	vim.fn.settabvar(tabnr, "tab_group_id", gid)
end

-- Get the working directory for a given tab (used for display only)
local function get_tab_cwd(tabnr)
	-- Try to get the tab-local directory first (set via :tcd)
	local ok, cwd = pcall(vim.fn.getcwd, -1, tabnr)
	if ok and cwd ~= "" then
		return vim.fn.fnamemodify(cwd, ":p")
	end
	-- Fallback to global cwd
	return vim.fn.fnamemodify(vim.fn.getcwd(), ":p")
end

-- Get display name for a tab (shortened path or buffer name)
local function get_tab_label(tabnr)
	local winnr = vim.fn.tabpagewinnr(tabnr)
	local buflist = vim.fn.tabpagebuflist(tabnr)
	local bufnr = buflist[winnr]
	local bufname = vim.fn.bufname(bufnr)

	if bufname == "" then
		return "[No Name]"
	end

	-- Show just the filename
	return vim.fn.fnamemodify(bufname, ":t")
end

-- Check if buffer in tab is modified
local function is_tab_modified(tabnr)
	local buflist = vim.fn.tabpagebuflist(tabnr)
	for _, bufnr in ipairs(buflist) do
		if vim.fn.getbufvar(bufnr, "&modified") == 1 then
			return true
		end
	end
	return false
end

-- Get all unique tab groups (by group ID) and their first tab
local function get_tab_groups()
	local groups = {} -- ordered list of { gid, first_tab }
	local seen_gids = {}

	for tabnr = 1, vim.fn.tabpagenr("$") do
		local gid = get_tab_group(tabnr)
		if not seen_gids[gid] then
			seen_gids[gid] = true
			table.insert(groups, { gid = gid, first_tab = tabnr })
		end
	end

	return groups
end

-- Get short display name for a directory
local function get_dir_display_name(cwd, max_width)
	local dir_name = vim.fn.fnamemodify(cwd, ":~:t")
	if dir_name == "" then
		dir_name = vim.fn.fnamemodify(cwd, ":~")
	end
	-- Truncate from the beginning if too long (prioritize end)
	if max_width and #dir_name > max_width then
		dir_name = "…" .. dir_name:sub(-(max_width - 1))
	end
	return dir_name
end

-- Return the _default_tab for a group if set and still in that group, else nil
local function get_default_tab(gid)
	local tabnr = vim.tg[gid]._default_tab
	if tabnr and get_tab_group(tabnr) == gid then
		return tabnr
	end
	return nil
end

-- Get tabs in the current group
local function get_tabs_in_group()
	local current_gid = get_tab_group(vim.fn.tabpagenr())
	local matching_tabs = {}
	for tabnr = 1, vim.fn.tabpagenr("$") do
		if get_tab_group(tabnr) == current_gid then
			table.insert(matching_tabs, tabnr)
		end
	end
	return matching_tabs
end

-- Build the custom tabline
function M.tabline()
	local s = ""
	local current_tab = vim.fn.tabpagenr()
	local current_gid = get_tab_group(current_tab)
	local total_tabs = vim.fn.tabpagenr("$")

	-- Collect tabs in the current group
	local matching_tabs = {}

	for tabnr = 1, total_tabs do
		if get_tab_group(tabnr) == current_gid then
			table.insert(matching_tabs, tabnr)
		end
	end

	-- LEFT SIDE: Tabs of the current tab group
	for i, tabnr in ipairs(matching_tabs) do
		local is_current = (tabnr == current_tab)
		local label = get_tab_label(tabnr)
		local modified = is_tab_modified(tabnr) and " ●" or ""

		-- Highlight group
		if is_current then
			s = s .. "%#TabLineSel#"
		else
			s = s .. "%#TabLine#"
		end

		-- Clickable tab (allows clicking to switch)
		s = s .. "%" .. tabnr .. "T"

		-- Tab content with padding
		s = s .. " " .. label .. modified .. " "

		-- Add separator between tabs (not after the last one)
		if i < #matching_tabs then
			s = s .. "%#TabLineFill#│"
		end
	end

	-- Fill the rest with TabLineFill and reset click target
	s = s .. "%#TabLineFill#%T"

	-- RIGHT SIDE: List of all tab groups
	s = s .. "%="

	local groups = get_tab_groups()

	-- Build the tab groups section
	for i, group in ipairs(groups) do
		local is_current_group = (group.gid == current_gid)
		-- Prefer explicit name, fall back to auto-generated name
		local dir_name = get_group_name(group.gid) or ("Tab Group " .. group.gid)

		-- Add separator before (except for first)
		if i > 1 then
			s = s .. "%#TabLineFill#│"
		end

		-- Highlight current group
		if is_current_group then
			s = s .. "%#TabLineSel#"
		else
			s = s .. "%#TabLine#"
		end

		-- Clickable (jumps to first tab in group)
		s = s .. "%" .. group.first_tab .. "T"

		-- Group content
		s = s .. " " .. dir_name .. " "
	end

	-- Reset click target
	s = s .. "%#TabLineFill#%T"

	return s
end

-- Cycle to the next tab within the current tab group
function M.next_tab_in_group()
	local current_tab = vim.fn.tabpagenr()
	local matching_tabs = get_tabs_in_group()

	if #matching_tabs <= 1 then
		return
	end

	-- Find current tab index within the group
	local current_idx = 1
	for i, tabnr in ipairs(matching_tabs) do
		if tabnr == current_tab then
			current_idx = i
			break
		end
	end

	-- Get next tab in group (wrap around)
	local next_idx = (current_idx % #matching_tabs) + 1
	vim.cmd("tabnext " .. matching_tabs[next_idx])
end

-- Cycle to the previous tab within the current tab group
function M.prev_tab_in_group()
	local current_tab = vim.fn.tabpagenr()
	local matching_tabs = get_tabs_in_group()

	if #matching_tabs <= 1 then
		return
	end

	-- Find current tab index within the group
	local current_idx = 1
	for i, tabnr in ipairs(matching_tabs) do
		if tabnr == current_tab then
			current_idx = i
			break
		end
	end

	-- Get previous tab in group (wrap around)
	local prev_idx = ((current_idx - 2) % #matching_tabs) + 1
	vim.cmd("tabnext " .. matching_tabs[prev_idx])
end

-- Cycle to the next tab group
function M.next_tab_group()
	local current_gid = get_tab_group(vim.fn.tabpagenr())
	local groups = get_tab_groups()

	if #groups <= 1 then
		vim.notify("Only one tab group exists", vim.log.levels.INFO)
		return
	end

	-- Find current group index
	local current_group_idx = 1
	for i, group in ipairs(groups) do
		if group.gid == current_gid then
			current_group_idx = i
			break
		end
	end

	-- Get next group (wrap around)
	local next_group_idx = (current_group_idx % #groups) + 1
	local next_group = groups[next_group_idx]
	local target = get_default_tab(next_group.gid) or next_group.first_tab
	vim.cmd("tabnext " .. target)
end

-- Cycle to the previous tab group
function M.prev_tab_group()
	local current_gid = get_tab_group(vim.fn.tabpagenr())
	local groups = get_tab_groups()

	if #groups <= 1 then
		vim.notify("Only one tab group exists", vim.log.levels.INFO)
		return
	end

	-- Find current group index
	local current_group_idx = 1
	for i, group in ipairs(groups) do
		if group.gid == current_gid then
			current_group_idx = i
			break
		end
	end

	-- Get previous group (wrap around)
	local prev_group_idx = ((current_group_idx - 2) % #groups) + 1
	local prev_group = groups[prev_group_idx]
	local target = get_default_tab(prev_group.gid) or prev_group.first_tab
	vim.cmd("tabnext " .. target)
end

-- Move the current tab into a selected tab group (interactive)
function M.move_current_tab()
	local current_tab = vim.fn.tabpagenr()
	local current_gid = get_tab_group(current_tab)
	local groups = get_tab_groups()

	-- Build display items (exclude current group); prepend "New Group" option
	local items = { { gid = nil, label = "[ New Group ]" } }
	for _, group in ipairs(groups) do
		if group.gid ~= current_gid then
			table.insert(items, {
				gid = group.gid,
				label = get_group_name(group.gid)
					or get_dir_display_name(get_tab_cwd(group.first_tab), 40),
			})
		end
	end

	vim.ui.select(items, {
		prompt = "Move tab into group:",
		format_item = function(item)
			return item.label
		end,
	}, function(choice)
		if not choice then
			return
		end
		local gid = choice.gid or new_group_id()
		set_tab_group(current_tab, gid)
		vim.cmd("redrawtabline")
	end)
end

-- Open a new tab in a new tab group; name can be passed directly or prompted
function M.new_group(name)
	local gid = new_group_id()
	local function create_tab()
		vim.g.tab_group_new_override = gid
		vim.cmd("tabnew")
		vim.g.tab_group_new_override = nil
		if name then
			set_group_name(gid, name)
		end
		vim.cmd("redrawtabline")
	end
	if name then
		create_tab()
	else
		vim.ui.input({ prompt = "Group name: " }, function(input)
			if input ~= nil then
				name = input ~= "" and input or nil
			end
			create_tab()
		end)
	end
end

-- Rename the current tab group; name can be passed directly or prompted
function M.rename_current_group(name)
	local gid = get_tab_group(vim.fn.tabpagenr())
	local current_name = get_group_name(gid) or ""
	local function apply(n)
		if n ~= nil then
			set_group_name(gid, n)
			vim.cmd("redrawtabline")
		end
	end
	if name then
		apply(name)
	else
		vim.ui.input({ prompt = "Rename group: ", default = current_name }, apply)
	end
end


-- Internal functions used by plugin/tabgroups.lua (prefixed to signal non-public API)
M.get_tab_group = get_tab_group
M._set_tab_group = set_tab_group
M._new_group_id = new_group_id


return M
