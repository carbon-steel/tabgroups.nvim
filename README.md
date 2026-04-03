# tabgroups.nvim

Organize Neovim tabs into named groups. Each tab belongs to a group; the tabline shows only the tabs in the current group, with all groups listed on the right.

## Features

- Named tab groups with persistent group IDs per session
- Tabline shows current group's tabs on the left, all groups on the right
- New tabs inherit the group of the tab they were opened from
- Closing a tab returns focus to the same group
- Interactive commands to create, rename, and move tabs between groups

## Installation

**lazy.nvim** (from GitHub):
```lua
{
  "yourusername/tabgroups.nvim",
  config = function()
    local tabgroups = require("tabgroups")

    -- Options
    vim.o.tabline = "%!v:lua.require('tabgroups').tabline()"
    vim.o.showtabline = 2  -- 0 = never, 1 = 2+ tabs, 2 = always

    vim.api.nvim_set_hl(0, "TabLineDirBold", { link = "TabLineFill", bold = true })

    -- Keymaps
    vim.keymap.set("n", "<Tab>",   tabgroups.next_tab_in_group, { desc = "Next tab in group" })
    vim.keymap.set("n", "<S-Tab>", tabgroups.prev_tab_in_group, { desc = "Previous tab in group" })
    vim.keymap.set("n", "<Right>", tabgroups.next_tab_group,    { desc = "Next tab group" })
    vim.keymap.set("n", "<Left>",  tabgroups.prev_tab_group,    { desc = "Previous tab group" })
  end,
}
```

**lazy.nvim** (local development):
```lua
{
  dir = vim.fn.expand("~/code/tabgroups.nvim"),
  name = "tabgroups.nvim",
  config = function()
    -- same config block as above
  end,
}
```

## Configuration

There is no `setup()` function. Configure the plugin directly in your lazy `config` function:

- Set `vim.o.tabline` to enable the custom tabline renderer
- Set `vim.o.showtabline` to control when the tabline is visible
- Map the navigation functions to whatever keys you prefer

## Keymaps

The plugin does not set any keymaps automatically. Map the public navigation functions yourself:

| Function                        | Suggested key | Action                        |
|---------------------------------|---------------|-------------------------------|
| `tabgroups.next_tab_in_group()` | `<Tab>`       | Next tab in current group     |
| `tabgroups.prev_tab_in_group()` | `<S-Tab>`     | Previous tab in current group |
| `tabgroups.next_tab_group()`    | `<Right>`     | Next tab group                |
| `tabgroups.prev_tab_group()`    | `<Left>`      | Previous tab group            |

## Commands

| Command                   | Description                                      |
|---------------------------|--------------------------------------------------|
| `:TabGroupNew [name]`     | Open a new tab in a new group (prompts if no name given) |
| `:TabGroupRename [name]`  | Rename the current group (prompts if no name given) |
| `:TabGroupMove`           | Move the current tab to a different group (interactive picker) |

## Development

### Run tests

Requires [luarocks][luarocks] or [busted][busted] + [nlua][nlua].

```bash
luarocks test --local
# or
busted
```

Single file:
```bash
busted spec/tabgroups_spec.lua
```

If you see `module 'busted.runner' not found`:
```bash
eval $(luarocks path --no-bin)
```

Luarocks must be configured for Lua 5.1. Pass `--lua-version 5.1` if needed.

[luarocks]: https://luarocks.org
[busted]: https://lunarmodules.github.io/busted/
[nlua]: https://github.com/mfussenegger/nlua
