# Telescope Integration - Requirements & Implementation Guide

## Overview

This document outlines the requirements and implementation plan for integrating Telescope.nvim with markdown-backlinks.nvim to provide enhanced UX for browsing backlinks, orphans, and dead links.

## Complexity Assessment

**Overall Complexity: 6/10**
- **Dependencies**: Requires telescope.nvim (optional)
- **Code Complexity**: Medium (need to learn Telescope API)
- **Maintenance**: Low (stable Telescope API)
- **Testing**: Medium (need Telescope installed)

## Why Telescope?

### Benefits Over Quickfix List

| Feature | Quickfix | Telescope |
|---------|----------|-----------|
| Fuzzy search | ❌ | ✅ |
| Live preview | ❌ | ✅ |
| Custom actions | Limited | ✅ |
| UI/UX | Basic | Beautiful |
| Sorting | Fixed | Flexible |
| Multi-select | ❌ | ✅ |

### User Experience Improvements

1. **Fuzzy Finding**: Type to filter backlinks instantly
2. **Preview**: See file content before jumping
3. **Custom Actions**: Jump, open in split, yank path, etc.
4. **Better Visuals**: Icons, highlights, structured display
5. **Multi-select**: Operate on multiple results at once

---

## Requirements

### 1. Dependencies

**Required (optional for users):**
- `nvim-telescope/telescope.nvim` >= 0.1.0
- `nvim-lua/plenary.nvim` (telescope dependency)

**Optional enhancements:**
- `nvim-tree/nvim-web-devicons` (for file icons)

### 2. Module Structure

```
lua/
├── markdown-backlinks/
│   ├── init.lua                    # Existing
│   ├── backlink_finder.lua         # Existing
│   └── telescope/
│       ├── init.lua                # Telescope integration entry
│       ├── pickers.lua             # Custom pickers
│       └── actions.lua             # Custom actions
└── telescope/_extensions/
    └── markdown_backlinks.lua       # Telescope extension registration
```

---

## Implementation Plan

### Phase 1: Basic Picker (Simple)

**Goal**: Create a basic Telescope picker for backlinks

**Files to Create:**
- `lua/markdown-backlinks/telescope/pickers.lua`
- `lua/telescope/_extensions/markdown_backlinks.lua`

**Code Structure:**

```lua
-- lua/markdown-backlinks/telescope/pickers.lua
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local entry_display = require("telescope.pickers.entry_display")

local M = {}

-- Backlinks picker
function M.backlinks(opts)
  opts = opts or {}

  local backlink_finder = require("markdown-backlinks.backlink_finder")
  local current_file = vim.api.nvim_buf_get_name(0)

  -- Get backlinks
  local backlinks = backlink_finder.find_backlinks_to_file(current_file)

  if #backlinks == 0 then
    vim.notify("No backlinks found", vim.log.levels.INFO)
    return
  end

  -- Create entry maker for better display
  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 30 },  -- Filename
      { remaining = true },  -- Context
    },
  })

  local make_entry = function(backlink)
    return {
      value = backlink,
      display = function(entry)
        return displayer({
          entry.value.file:match("([^/]+)$"),  -- Filename only
          entry.value.context,
        })
      end,
      ordinal = backlink.file .. " " .. backlink.context,
      filename = backlink.file,
      lnum = backlink.line_num,
    }
  end

  pickers.new(opts, {
    prompt_title = "Backlinks to " .. current_file:match("([^/]+)$"),
    finder = finders.new_table({
      results = backlinks,
      entry_maker = make_entry,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = conf.file_previewer(opts),
  }):find()
end

return M
```

**Extension Registration:**

```lua
-- lua/telescope/_extensions/markdown_backlinks.lua
local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then
  error("This extension requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)")
end

return telescope.register_extension({
  setup = function(ext_config, config)
    -- Optional: merge user config
  end,
  exports = {
    backlinks = require("markdown-backlinks.telescope.pickers").backlinks,
    orphans = require("markdown-backlinks.telescope.pickers").orphans,
    dead_links = require("markdown-backlinks.telescope.pickers").dead_links,
  },
})
```

---

### Phase 2: All Three Pickers (Medium)

**Pickers to Implement:**

1. **`:Telescope markdown_backlinks backlinks`**
   - Show backlinks to current file
   - Preview: Show the linking file with context

2. **`:Telescope markdown_backlinks orphans`**
   - Show all orphaned notes
   - Preview: Show the orphaned file content

3. **`:Telescope markdown_backlinks dead_links`**
   - Show all dead links in workspace
   - Preview: Show the source file with broken link

---

### Phase 3: Custom Actions (Advanced)

**Custom Actions to Add:**

```lua
-- lua/markdown-backlinks/telescope/actions.lua
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local M = {}

-- Open in vertical split
M.open_vsplit = function(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  actions.close(prompt_bufnr)
  vim.cmd("vsplit " .. selection.filename)
  vim.api.nvim_win_set_cursor(0, { selection.lnum, 0 })
end

-- Create backlink immediately
M.create_backlink = function(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  local backlink_manager = require("markdown-backlinks.backlink_manager")
  local current_file = vim.api.nvim_buf_get_name(0)

  backlink_manager.ensure_backlink(selection.filename, current_file)
  vim.notify("Backlink created!", vim.log.levels.INFO)
end

-- Fix dead link (interactive)
M.fix_dead_link = function(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  -- Prompt user for corrected path
  vim.ui.input({ prompt = "Fix link to: " }, function(input)
    if input then
      -- Update the link in the file
      -- Implementation here
    end
  end)
end

return M
```

**Key Mappings:**

```lua
attach_mappings = function(prompt_bufnr, map)
  local custom_actions = require("markdown-backlinks.telescope.actions")

  -- Default: <CR> opens file
  actions.select_default:replace(function()
    actions.close(prompt_bufnr)
    local selection = action_state.get_selected_entry()
    vim.cmd("edit " .. selection.filename)
    vim.api.nvim_win_set_cursor(0, { selection.lnum, 0 })
  end)

  -- Custom mappings
  map("i", "<C-v>", custom_actions.open_vsplit)
  map("n", "<C-v>", custom_actions.open_vsplit)
  map("i", "<C-b>", custom_actions.create_backlink)
  map("n", "<C-b>", custom_actions.create_backlink)

  return true
end
```

---

## Integration with Existing Code

### Update init.lua

Add Telescope commands alongside quickfix commands:

```lua
-- Register Telescope commands (if telescope available)
local has_telescope = pcall(require, "telescope")

if has_telescope then
  vim.api.nvim_create_user_command("MarkdownBacklinkListTelescope", function()
    require("telescope").extensions.markdown_backlinks.backlinks()
  end, {
    desc = "List backlinks using Telescope",
  })

  -- OR just recommend users use:
  -- :Telescope markdown_backlinks backlinks
end
```

### Graceful Fallback

```lua
-- In init.lua
function M.list_backlinks()
  local has_telescope = pcall(require, "telescope")

  if has_telescope then
    -- Use Telescope
    require("telescope").extensions.markdown_backlinks.backlinks()
  else
    -- Fallback to quickfix
    M._list_backlinks_quickfix()
  end
end
```

---

## Configuration

### User Configuration

```lua
-- In lazy.nvim config
{
  "randerson911/markdown-backlinks.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",  -- Optional but recommended
  },
  config = function()
    require("markdown-backlinks").setup({
      -- Existing config...

      -- Telescope-specific options
      telescope = {
        enabled = true,  -- Use telescope if available
        mappings = {
          i = {
            ["<C-v>"] = "open_vsplit",
            ["<C-b>"] = "create_backlink",
          },
          n = {
            ["<C-v>"] = "open_vsplit",
            ["<C-b>"] = "create_backlink",
          },
        },
      },
    })

    -- Load telescope extension
    require("telescope").load_extension("markdown_backlinks")
  end,
}
```

---

## Testing Strategy

### Manual Testing

1. **Without Telescope**: Ensure quickfix still works
2. **With Telescope**: Test all pickers
3. **Custom Actions**: Test all keybindings
4. **Preview**: Verify preview window shows correct content
5. **Large Files**: Test performance with many results

### Test Cases

```lua
-- test/telescope_spec.lua
describe("telescope integration", function()
  it("should fallback to quickfix when telescope not installed", function()
    -- Test fallback behavior
  end)

  it("should show backlinks in telescope picker", function()
    -- Test telescope picker
  end)

  it("should handle empty results gracefully", function()
    -- Test empty state
  end)
end)
```

---

## File Checklist

### Files to Create

- [ ] `lua/markdown-backlinks/telescope/init.lua`
- [ ] `lua/markdown-backlinks/telescope/pickers.lua`
- [ ] `lua/markdown-backlinks/telescope/actions.lua`
- [ ] `lua/telescope/_extensions/markdown_backlinks.lua`
- [ ] Update `lua/markdown-backlinks/init.lua` (add telescope commands)
- [ ] Update `lua/markdown-backlinks/config.lua` (add telescope config)
- [ ] Update `README.md` (document telescope integration)
- [ ] Update `FEATURES.md` (mark as complete)

---

## API Reference

### Telescope Modules Needed

```lua
-- Core modules
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values

-- Display helpers
local entry_display = require("telescope.pickers.entry_display")

-- Actions
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

-- Previewers (built-in)
conf.file_previewer(opts)        -- Preview files
conf.grep_previewer(opts)        -- Preview with grep
```

### Entry Format

```lua
{
  value = original_data,           -- Raw data
  display = "Display Text",        -- What user sees
  ordinal = "searchable text",     -- What fuzzy search matches
  filename = "/path/to/file.md",   -- For file preview
  lnum = 42,                       -- Line number
  col = 10,                        -- Column (optional)
}
```

---

## Pros & Cons

### Pros ✅

- **Much better UX** - Fuzzy search, preview, pretty UI
- **Industry standard** - Most users have Telescope
- **Extensible** - Easy to add custom actions
- **Optional** - Can still use quickfix as fallback
- **Consistent** - Matches Telescope's existing pickers

### Cons ❌

- **Dependency** - Adds telescope as (optional) dependency
- **Complexity** - More code to maintain
- **Learning curve** - Team needs to know Telescope API
- **Testing** - Harder to test without Telescope installed

---

## Alternative: FZF-Lua

If you want to support both Telescope AND fzf-lua:

**Complexity: 8/10** (need to implement twice)

```lua
-- Check which is available and use it
local has_telescope = pcall(require, "telescope")
local has_fzf = pcall(require, "fzf-lua")

if has_telescope then
  -- Use telescope
elseif has_fzf then
  -- Use fzf-lua (different API)
else
  -- Use quickfix
end
```

**Recommendation**: Start with Telescope only. It's more popular and has better docs.

---

## Estimated Effort

### Time Breakdown

- **Phase 1** (Basic Picker): 2-3 hours
  - Create pickers.lua
  - Register extension
  - Test basic functionality

- **Phase 2** (All Pickers): 2-3 hours
  - Implement orphans picker
  - Implement dead_links picker
  - Test all three

- **Phase 3** (Custom Actions): 3-4 hours
  - Implement custom actions
  - Add keybindings
  - Polish UX

- **Documentation & Testing**: 2 hours
  - Update README
  - Create examples
  - Test edge cases

**Total: 9-12 hours**

---

## Recommendation

### Should You Implement This?

**YES if:**
- ✅ You want best-in-class UX
- ✅ Most users have Telescope installed
- ✅ You plan to add more features later
- ✅ You want to match obsidian.nvim's UX

**NO if:**
- ❌ You want to keep plugin minimal
- ❌ Quickfix is "good enough"
- ❌ You don't want external dependencies
- ❌ Limited time for this project

### My Recommendation: **YES, but make it optional**

Implementation approach:
1. Keep quickfix as default (no dependencies)
2. Auto-detect Telescope and use it if available
3. Document both methods in README
4. Mark as "enhanced UX" feature

This gives users choice and makes the plugin work standalone!

---

## Next Steps

If you want to proceed:

1. **Start with Phase 1** - Basic backlinks picker
2. **Test thoroughly** - Make sure it works
3. **Get feedback** - See if users like it
4. **Expand** - Add orphans and dead_links pickers
5. **Polish** - Add custom actions

Want me to implement Phase 1 now?
