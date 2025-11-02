# Testing Guide for markdown-backlink.nvim

This guide provides step-by-step instructions for manually testing all plugin capabilities.

## Setup

1. **Install the plugin** in your NeoVim configuration:

```lua
{
  "yourusername/markdown-backlink.nvim",
  dir = "/opt/projects/NeoVim/markdown-backlink",  -- Use local directory
  ft = "markdown",
  opts = {
    notify = true,  -- Enable notifications to see what's happening
  },
}
```

2. **Restart NeoVim** or reload your configuration

3. **Navigate to test directory**:
```bash
cd /opt/projects/NeoVim/markdown-backlink/test/fixtures/notes
nvim .
```

## Phase 1: Basic Link Detection (Markdown Format)

### Test 1.1: Simple Relative Link

1. Open `index.md`
2. Add a new link: `[Test Link](projects/beta.md)`
3. Save the file (`:w`) or leave insert mode
4. **Expected**: Notification "Added backlink in beta.md"
5. **Verify**: Open `projects/beta.md` and check for:
```markdown
## Backlinks

- [index](../index.md)
```

### Test 1.2: Nested Directory Link

1. Open `projects/alpha.md`
2. The file already has: `[Beta Project](beta.md)`
3. Save the file (`:w`)
4. **Expected**: Notification "Added backlink in beta.md"
5. **Verify**: Open `projects/beta.md` and check it now has TWO backlinks:
```markdown
## Backlinks

- [index](../index.md)
- [alpha](alpha.md)
```

### Test 1.3: Cross-Directory Link

1. Open `projects/alpha.md`
2. The file already has: `[AI Research](../research/ai-notes.md)`
3. Save the file (`:w`)
4. **Expected**: Notification "Added backlink in ai-notes.md"
5. **Verify**: Open `research/ai-notes.md` and check for:
```markdown
## Backlinks

- [alpha](../projects/alpha.md)
```

## Phase 2: Wiki-Style Links

### Test 2.1: Configure Wiki Format

1. Update your plugin config:
```lua
opts = {
  link_format = "wiki",
  notify = true,
}
```

2. Restart NeoVim

### Test 2.2: Wiki Link Creation

1. Create new file `test/fixtures/notes/wiki-test.md`:
```markdown
# Wiki Test

Check out [[research/ai-notes]] for more info.
```

2. Save the file
3. **Expected**: Notification "Added backlink in ai-notes.md"
4. **Verify**: Open `research/ai-notes.md` and check it now has:
```markdown
## Backlinks

- [alpha](../projects/alpha.md)
- [[../wiki-test]]
```

## Phase 3: Edge Cases

### Test 3.1: Links in Code Blocks (Should be Ignored)

1. Create `test/fixtures/notes/code-test.md`:
````markdown
# Code Test

Here's a normal link: [Project Alpha](projects/alpha.md)

Here's a code block (should be ignored):

```markdown
[Fake Link](projects/beta.md)
```

And inline code: `[Another Fake](projects/beta.md)`
````

2. Save the file
3. **Expected**: Only ONE backlink created (for Project Alpha)
4. **Verify**: `projects/alpha.md` should have backlink to code-test, but `projects/beta.md` should NOT

### Test 3.2: Links with Anchors

1. Create `test/fixtures/notes/anchor-test.md`:
```markdown
# Anchor Test

Link to specific section: [AI Topics](research/ai-notes.md#topics)
```

2. Save the file
3. **Expected**: Backlink created (anchor is stripped)
4. **Verify**: `research/ai-notes.md` has backlink to anchor-test

### Test 3.3: Duplicate Link Detection

1. Open `index.md`
2. Add the same link twice:
```markdown
- [Project Alpha](projects/alpha.md)
- [Project Alpha Again](projects/alpha.md)
```

3. Save the file
4. **Expected**: Only ONE backlink in `projects/alpha.md` (no duplicates)

### Test 3.4: Non-Existent File

1. Create `test/fixtures/notes/broken-link.md`:
```markdown
# Broken Links

This file doesn't exist: [Ghost](ghost.md)
```

2. Save the file
3. **Expected**: No error, no backlink created (file doesn't exist)

## Phase 4: Manual Commands

### Test 4.1: MarkdownBacklinkCheck

1. Open any file with links (e.g., `index.md`)
2. Run `:MarkdownBacklinkCheck`
3. **Expected**: Report showing which links have/don't have backlinks

### Test 4.2: MarkdownBacklinkCreate

1. Disable auto-creation: `:MarkdownBacklinkDisable`
2. Create new file with links
3. Save (no backlinks should be created)
4. Run `:MarkdownBacklinkCreate`
5. **Expected**: Backlinks created manually

### Test 4.3: Enable/Disable

1. `:MarkdownBacklinkDisable`
2. **Expected**: Notification "Automatic backlink creation disabled"
3. Add links (no backlinks created)
4. `:MarkdownBacklinkEnable`
5. **Expected**: Notification "Automatic backlink creation enabled"
6. Add links (backlinks created)

## Phase 5: Workspace Constraints

### Test 5.1: Outside Workspace (Default: Blocked)

1. Ensure config has `workspace_only = true`
2. Open a file in the test directory
3. Add link to file OUTSIDE current working directory (e.g., `/tmp/test.md`)
4. Save the file
5. **Expected**: No backlink created (outside workspace)

### Test 5.2: Disable Workspace Constraint

1. Update config:
```lua
opts = {
  workspace_only = false,
}
```

2. Restart NeoVim
3. Repeat Test 5.1
4. **Expected**: Backlink created (workspace constraint disabled)

## Phase 6: Performance Testing

### Test 6.1: Debouncing

1. Open any markdown file
2. Enter insert mode and type rapidly (adding/removing characters)
3. **Expected**: No notifications/processing while typing
4. Leave insert mode
5. **Expected**: Processing happens ONCE after debounce delay (~500ms)

### Test 6.2: Large File

1. Create a file with 1000+ lines and many links
2. Save the file
3. **Expected**: Processing completes without lag

## Phase 7: Integration with Other Plugins

### Test 7.1: With Marksman LSP

If you have marksman installed:

1. Open a markdown file
2. Type `[` and start typing a filename
3. Use LSP completion to complete the link
4. Save the file
5. **Expected**: Backlink created (works with LSP completion)

### Test 7.2: With obsidian.nvim

If you have obsidian.nvim installed:

1. Use obsidian.nvim's link creation command
2. **Expected**: Backlink created (works with any plugin)

## Troubleshooting

### Check Plugin is Loaded

```vim
:lua print(vim.inspect(package.loaded["markdown-backlink"]))
```

Should show the plugin module.

### Check Autocmds are Registered

```vim
:autocmd MarkdownBacklink
```

Should show InsertLeave, TextChanged, and BufWritePost autocmds.

### Enable Debug Logging

Temporarily modify `utils.lua` to always show notifications:

```lua
function M.notify(msg, level)
  -- Remove config check for debugging
  level = level or vim.log.levels.INFO
  vim.notify("markdown-backlink: " .. msg, level)
end
```

### Check File Paths

Run this in a markdown buffer:

```vim
:lua print(vim.api.nvim_buf_get_name(0))
```

Should show absolute path to current file.

## Test Checklist

Use this checklist to ensure all features are tested:

- [ ] Basic markdown link detection `[text](path.md)`
- [ ] Wiki link detection `[[path]]`
- [ ] Relative paths (`./`, `../`)
- [ ] Same directory links
- [ ] Cross-directory links
- [ ] Backlink section creation
- [ ] Backlink insertion (markdown format)
- [ ] Backlink insertion (wiki format)
- [ ] Duplicate detection
- [ ] Code block exclusion
- [ ] Inline code exclusion
- [ ] Anchor stripping
- [ ] Non-existent file handling
- [ ] `:MarkdownBacklinkCreate` command
- [ ] `:MarkdownBacklinkCheck` command
- [ ] `:MarkdownBacklinkEnable` command
- [ ] `:MarkdownBacklinkDisable` command
- [ ] Workspace constraint (enabled)
- [ ] Workspace constraint (disabled)
- [ ] Debouncing behavior
- [ ] Integration with LSP
- [ ] Integration with other markdown plugins

## Expected Directory Structure After Testing

After running all tests, your test directory should look like:

```
test/fixtures/notes/
├── index.md (with backlinks section)
├── projects/
│   ├── alpha.md (with backlinks section)
│   └── beta.md (with backlinks section)
├── research/
│   └── ai-notes.md (with backlinks section)
├── daily/
│   └── 2025-01-15.md (with backlinks section)
├── wiki-test.md (optional, if wiki tests run)
├── code-test.md (optional, if edge case tests run)
├── anchor-test.md (optional, if edge case tests run)
└── broken-link.md (optional, if edge case tests run)
```

## Clean Up

To reset test fixtures to original state:

```bash
cd /opt/projects/NeoVim/markdown-backlink
git checkout test/fixtures/
# or manually remove ## Backlinks sections from files
```

## Reporting Issues

If you find bugs during testing:

1. Note the exact steps to reproduce
2. Check `:messages` for any error messages
3. Include your configuration
4. Note which test case failed

---

Happy Testing! 🧪
