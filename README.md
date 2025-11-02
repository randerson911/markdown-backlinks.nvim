# markdown-backlink.nvim

A lightweight, event-driven NeoVim plugin that automatically manages bidirectional links in your markdown notes.

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
  "yourusername/markdown-backlink.nvim",
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
  "yourusername/markdown-backlink.nvim",
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
git clone https://github.com/yourusername/markdown-backlink.nvim \
  ~/.local/share/nvim/site/pack/plugins/start/markdown-backlink.nvim
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
| `:MarkdownBacklinkDisable` | Temporarily disable auto-creation |
| `:MarkdownBacklinkEnable` | Re-enable auto-creation |

## Keymaps

No default keymaps are provided. Add your own:

```lua
-- Example keymaps (add to your config)
vim.keymap.set("n", "<leader>mb", ":MarkdownBacklinkCreate<CR>", { desc = "Create backlinks" })
vim.keymap.set("n", "<leader>mc", ":MarkdownBacklinkCheck<CR>", { desc = "Check backlinks" })
```

## Autocmds

The plugin automatically creates these autocmds for markdown files:

- `InsertLeave` - Detects links when exiting insert mode
- `TextChanged` - Detects links when text changes in normal mode
- `BufWritePost` - Ensures backlinks are synced on save

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

## Roadmap

- [ ] Support for custom backlink section names
- [ ] Configurable backlink list format (bullets, numbered, etc.)
- [ ] Orphaned link detection
- [ ] Graph view integration (via external tools)

## Contributing

Contributions welcome! Please open an issue or PR.

## License

MIT License - see LICENSE file for details.
