# markdown-backlink.nvim

A lightweight, event-driven NeoVim plugin that automatically manages bidirectional links in your markdown notes. This project was generated with Claude AI support. As in, I provided the idea and a couple technical details, and just troubleshooted it. 

## Purpose

When you create a link from one markdown file to another, this plugin automatically adds a backlink in the target file. This enables Obsidian-style bidirectional linking without requiring a specific notes app.

**Key Features:**
- **Plugin-agnostic**: Works with manual typing, marksman LSP, obsidian.nvim, mkdnflow, or any markdown plugin
- **Event-driven**: No filesystem scanning - listens to buffer events for performance
- **Non-invasive**: Only modifies markdown files, only when links are created
- **Configurable**: Control backlink format, auto-enable, and more

## How It Works

1. You create a link: `[My Note](./notes/other.md)`
2. Plugin detects the link via buffer events
3. Plugin resolves the target file path
4. Plugin checks if a backlink already exists
5. If missing, adds backlink to `## Backlinks` section in target file

## Installation

### Lazy.nvim (Recommended)

```lua
{
  "randerson911/markdown-backlinks.nvim",
  ft = "markdown",  -- Only load for markdown files
  opts = {
    -- Optional configuration (see Configuration section)
  },
  -- Optional: Install marksman LSP for best link-creation UX
  dependencies = {
    -- "marksman",  -- Uncomment if you want link completion
  },
}
```

### Packer

```lua
use {
  "randerson911/markdown-backlinks.nvim",
  ft = "markdown",
  config = function()
    require("markdown-backlink").setup({
      -- Optional configuration
    })
  end
}
```

### Manual

```bash
# Clone to your NeoVim plugin directory
git clone https://github.com/randerson911/markdown-backlinks.nvim \
  ~/.local/share/nvim/site/pack/plugins/start/markdown-backlinks.nvim
```

## Usage

### Automatic Mode (Default)

Once installed, the plugin works automatically:

1. Open any markdown file
2. Create a link using any method:
   - Type manually: `[Text](file.md)`
   - Use LSP completion (if marksman installed)
   - Use obsidian.nvim, mkdnflow, or other plugins
   - Paste from clipboard
3. Save or leave insert mode
4. Backlink automatically added to target file

### Manual Mode

```vim
" Trigger backlink creation manually
:MarkdownBacklinkCreate

" Check for missing backlinks in current file
:MarkdownBacklinkCheck

" List all backlinks to current file (opens in quickfix)
:MarkdownBacklinkList

" Find all orphaned notes (notes with no backlinks)
:MarkdownBacklinkOrphans

" Find dead links in current file
:MarkdownBacklinkDeadLinks

" Find dead links in entire workspace
:MarkdownBacklinkDeadLinks all
```

## Configuration

Default configuration:

```lua
require("markdown-backlink").setup({
  -- Enable automatic backlink creation
  auto_create = true,

  -- Backlinks section header (must be heading level 2)
  backlinks_header = "## Backlinks",

  -- Link format for backlinks: "markdown" or "wiki"
  -- markdown: [Filename](path/to/file.md)
  -- wiki: [[path/to/file]]
  link_format = "markdown",

  -- Show notification when backlink is created
  notify = true,

  -- Only create backlinks for files within the same workspace
  -- (prevents linking to files outside your notes directory)
  workspace_only = true,

  -- Debounce time for text changes (in milliseconds)
  debounce_ms = 500,

  -- Auto-scan for dead links when opening markdown buffers
  scan_on_open = false,

  -- Show notifications for scan results
  scan_notify = true,
})
```

## Examples

### Example 1: Basic Link Creation

**File: `notes/project.md`**
```markdown
# Project Notes

Check out [My Research](research.md) for more details.
```

**Result in `notes/research.md`** (automatically added):
```markdown
# My Research

(existing content...)

## Backlinks

- [Project Notes](project.md)
```

### Example 2: Multiple Backlinks

**File: `notes/concept.md`**
```markdown
# Core Concept

This is referenced in multiple places.

## Backlinks

- [Project Notes](project.md)
- [Daily Note 2024-01-15](../daily/2024-01-15.md)
- [Ideas](ideas.md)
```

### Example 3: Wiki-style Links (Configuration)

```lua
-- In your lazy.nvim config:
opts = {
  link_format = "wiki",
}
```

**Result:**
```markdown
## Backlinks

- [[project]]
- [[daily/2024-01-15]]
```

## Commands

| Command | Description |
|---------|-------------|
| `:MarkdownBacklinkCreate` | Manually trigger backlink creation for links in current buffer |
| `:MarkdownBacklinkCheck` | List all links that are missing backlinks |
| `:MarkdownBacklinkList` | Show all backlinks to current file (opens quickfix list) |
| `:MarkdownBacklinkOrphans` | Find all orphaned notes (notes with no backlinks) |
| `:MarkdownBacklinkDeadLinks [all]` | Find dead/broken links (use `all` for entire workspace) |
| `:MarkdownBacklinkEnable` | Enable automatic backlink creation |
| `:MarkdownBacklinkDisable` | Disable automatic backlink creation |

## Keymaps

No default keymaps are provided. Add your own:

```lua
-- Example keymaps (add to your config)
vim.keymap.set("n", "<leader>mb", ":MarkdownBacklinkCreate<CR>", { desc = "Create backlinks" })
vim.keymap.set("n", "<leader>mc", ":MarkdownBacklinkCheck<CR>", { desc = "Check backlinks" })
vim.keymap.set("n", "<leader>ml", ":MarkdownBacklinkList<CR>", { desc = "List backlinks" })
vim.keymap.set("n", "<leader>mo", ":MarkdownBacklinkOrphans<CR>", { desc = "Find orphans" })
vim.keymap.set("n", "<leader>md", ":MarkdownBacklinkDeadLinks<CR>", { desc = "Find dead links" })
```

## Autocmds

The plugin automatically creates these autocmds for markdown files:

- `InsertLeave` - Detects links when exiting insert mode
- `TextChanged` - Detects links when text changes in normal mode
- `BufWritePost` - Ensures backlinks are synced on save
- `BufReadPost` - Auto-scans for dead links on buffer open (if `scan_on_open` enabled)

## Compatibility

**Works with:**
- marksman LSP
- obsidian.nvim
- mkdnflow.nvim
- Any markdown plugin that inserts text into buffers
- Manual typing

**Requirements:**
- NeoVim 0.8.0 or higher
- Markdown files only (`.md` extension)

## Suggested Companion Plugins

For the best markdown experience:

```lua
-- Link creation and completion
{ "artempyanykh/marksman" }  -- LSP for markdown (lightest)

-- OR if you want more features:
{ "jakewvincent/mkdnflow.nvim" }  -- Markdown notebook features
{ "epwalsh/obsidian.nvim" }       -- Full Obsidian integration
```

## Features

### Core Features ✅
- ✅ Automatic bidirectional link creation
- ✅ Plugin-agnostic (works with any markdown tool)
- ✅ Event-driven architecture (no filesystem scanning)
- ✅ Markdown `[text](path)` and Wiki `[[path]]` link support
- ✅ Configurable backlink format

### Quality of Life Features ✅ (NEW!)
- ✅ **Backlink Browser** - View all backlinks to current note
- ✅ **Orphan Detection** - Find notes with no backlinks
- ✅ **Dead Link Detection** - Find broken links
- ✅ **Auto-scan on Open** - Optional dead link scanning when opening files
- ✅ **Quickfix Integration** - Results displayed in native quickfix list

## Roadmap

- [x] Backlink browser (:MarkdownBacklinkList)
- [x] Orphaned note detection
- [x] Dead link detection
- [ ] File rename with auto-update all references
- [ ] Telescope/FZF integration for better UX
- [ ] Support for custom backlink section names
- [ ] Configurable backlink list format (bullets, numbered, etc.)
- [ ] Graph view integration (via external tools)
- [ ] LSP diagnostics for dead links
- [ ] Heading/anchor link support

## Contributing

I may or may not ever return to this, but it's just a proof of concept over anything else. I mostly use Obsidian so this is more another tool to try and keep my in my terminal.

## License

MIT License - see LICENSE file for details.
