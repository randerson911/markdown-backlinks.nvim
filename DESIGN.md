# markdown-backlinks.nvim - Technical Design Document

## Overview

An event-driven NeoVim plugin that automatically creates bidirectional links between markdown files. This document describes the technical architecture, implementation details, and design decisions.

## Core Principles

1. **Plugin-Agnostic**: Works regardless of how links are created (manual typing, LSP completion, or other plugins)
2. **Event-Driven**: Uses NeoVim autocmds to detect changes, no filesystem scanning
3. **Performance-First**: Minimal overhead, only processes markdown buffers
4. **Non-Invasive**: Only modifies files when necessary, preserves existing content

## Architecture

### Directory Structure

```
markdown-backlinks.nvim/
├── lua/
│   └── markdown-backlinks/
│       ├── init.lua              # Main entry point, setup()
│       ├── config.lua            # Configuration management
│       ├── events.lua            # Buffer event handlers
│       ├── link_detector.lua    # Detect markdown/wiki links
│       ├── path_resolver.lua    # Resolve relative/absolute paths
│       ├── backlink_manager.lua # Core backlink logic
│       └── utils.lua            # Helper functions
├── plugin/
│   └── markdown-backlinks.lua     # Auto-load plugin registration
├── test/
│   ├── fixtures/                 # Test markdown files
│   └── TESTING.md               # Manual testing guide
├── README.md
├── DESIGN.md                     # This file
└── LICENSE
```

## Module Breakdown

### 1. init.lua
**Purpose**: Main entry point for plugin initialization

**Responsibilities**:
- Expose `setup()` function
- Merge user configuration with defaults
- Initialize event listeners
- Register commands

**Public API**:
```lua
M.setup(opts)  -- Initialize plugin with config
M.enable()     -- Enable auto-backlink creation
M.disable()    -- Disable auto-backlink creation
```

### 2. config.lua
**Purpose**: Configuration management

**Default Configuration**:
```lua
{
  auto_create = true,           -- Auto-create backlinks
  backlinks_header = "## Backlinks",
  link_format = "markdown",     -- "markdown" or "wiki"
  notify = true,                -- Show notifications
  workspace_only = true,        -- Only link within workspace
  debounce_ms = 500,           -- Debounce for text changes
}
```

**Responsibilities**:
- Store configuration
- Validate configuration options
- Provide getters for config values

### 3. events.lua
**Purpose**: NeoVim event handling and buffer monitoring

**Event Strategy**:
```lua
-- Primary events for link detection:
autocmd InsertLeave *.md  -> check_for_new_links()
autocmd TextChanged *.md  -> check_for_new_links()
autocmd BufWritePost *.md -> check_for_new_links()
```

**Responsibilities**:
- Attach autocmds to markdown buffers
- Debounce rapid text changes (avoid performance issues)
- Cache last buffer state to detect new links
- Call link detector when changes occur

**Implementation Details**:
- Use `vim.api.nvim_create_autocmd()` for event handling
- Store buffer content hash to detect actual changes
- Implement debouncing via `vim.defer_fn()`

### 4. link_detector.lua
**Purpose**: Parse buffer content to find markdown links

**Link Patterns Supported**:
```lua
-- Markdown links: [text](path.md)
pattern_markdown = "%[.-%]%((.-)%)"

-- Wiki links: [[path]] or [[path|text]]
pattern_wiki = "%[%[(.-)%]%]"
```

**Responsibilities**:
- Scan buffer lines for link patterns
- Extract target paths from links
- Return list of detected links with metadata
- Handle edge cases (code blocks, inline code)

**Public API**:
```lua
M.find_links_in_buffer(bufnr) -> {
  {
    pattern = "markdown",    -- or "wiki"
    target = "path/to/file.md",
    line_num = 42,
    col_start = 10,
    col_end = 35,
  },
  ...
}
```

**Edge Cases**:
- Ignore links in code blocks (```)
- Ignore links in inline code (`...`)
- Ignore links in comments
- Handle malformed links gracefully

### 5. path_resolver.lua
**Purpose**: Resolve link paths relative to current file

**Responsibilities**:
- Convert relative paths to absolute paths
- Handle different link formats (./file.md, ../file.md, file.md)
- Validate target file exists
- Handle edge cases (symlinks, case sensitivity)

**Public API**:
```lua
M.resolve_link_path(current_file, link_target) -> absolute_path or nil

-- Example:
-- current_file: /home/user/notes/projects/idea.md
-- link_target:  ../research/paper.md
-- returns:      /home/user/notes/research/paper.md
```

**Algorithm**:
```lua
1. Get current file's directory
2. If link_target is absolute, return it
3. If link_target is relative:
   a. Join with current directory
   b. Normalize path (resolve .. and .)
   c. Add .md extension if missing
4. Check if resolved file exists
5. Return absolute path or nil
```

### 6. backlink_manager.lua
**Purpose**: Core backlink logic - detect and insert backlinks

**Responsibilities**:
- Check if target file has backlink to source
- Parse "## Backlinks" section
- Insert backlink if missing
- Create section if it doesn't exist

**Public API**:
```lua
M.ensure_backlink(source_file, target_file, link_format) -> boolean

-- Example:
-- source_file: /home/user/notes/project.md
-- target_file: /home/user/notes/research.md
-- Returns: true if backlink was added, false if already existed
```

**Algorithm**:
```lua
function ensure_backlink(source, target)
  1. Read target file content
  2. Find "## Backlinks" section
     - If not found, append to end of file
  3. Check if backlink to source already exists
     - Parse existing links in section
     - Compare normalized paths
  4. If missing:
     - Format backlink according to config.link_format
     - Insert into backlinks section
     - Write file
  5. Return true/false
end
```

**Backlink Format**:
```lua
-- Markdown format:
"- [Source Filename](relative/path/to/source.md)"

-- Wiki format:
"- [[relative/path/to/source]]"
```

**Edge Cases**:
- Multiple "## Backlinks" sections (use first)
- Backlink section in code block (ignore)
- File permissions (handle write failures)
- Concurrent modifications (atomic writes)

### 7. utils.lua
**Purpose**: Helper functions and utilities

**Functions**:
```lua
M.get_filename(path)              -- Extract filename from path
M.get_relative_path(from, to)    -- Get relative path between files
M.normalize_path(path)            -- Normalize path separators
M.file_exists(path)               -- Check if file exists
M.read_file(path)                 -- Read file contents
M.write_file(path, content)       -- Write file atomically
M.notify(msg, level)              -- Show notification to user
M.is_in_code_block(lines, line_num) -- Check if line is in code block
```

## Data Flow

### Link Creation Flow

```
User creates link in buffer
         ↓
Buffer event fires (InsertLeave/TextChanged)
         ↓
events.lua: Debounce and check for changes
         ↓
link_detector.lua: Find new link patterns
         ↓
path_resolver.lua: Resolve target file path
         ↓
backlink_manager.lua: Check if backlink exists
         ↓
If missing: Insert backlink into target file
         ↓
utils.lua: Show notification (optional)
```

### Buffer State Tracking

```lua
-- Cache strategy to detect NEW links only
buffer_cache = {
  [bufnr] = {
    last_check = timestamp,
    content_hash = hash(buffer_content),
    known_links = { "path/to/file1.md", "path/to/file2.md" }
  }
}

-- On buffer change:
1. Calculate new content hash
2. If hash unchanged, skip processing
3. If hash changed:
   - Detect all links in buffer
   - Compare with known_links
   - Process only NEW links
   - Update cache
```

## Testing Strategy

### Phase 1: Unit Testing (Manual)
Each module can be tested independently:

**test/fixtures/sample_notes/**
```
test/fixtures/sample_notes/
├── root.md
├── folder1/
│   ├── note1.md
│   └── note2.md
└── folder2/
    └── note3.md
```

**Testing Checklist**:
1. Link Detector:
   - Create file with various link formats
   - Verify all links are detected
   - Test edge cases (code blocks, etc.)

2. Path Resolver:
   - Test relative paths (./file, ../file, file)
   - Test nested directories
   - Test non-existent files

3. Backlink Manager:
   - Test creating new backlink section
   - Test adding to existing section
   - Test duplicate detection

4. Integration:
   - Create link from note1 to note2
   - Verify backlink appears in note2
   - Create another link to note2 from note3
   - Verify note2 has both backlinks

### Phase 2: Automated Testing (Future)
- Use plenary.nvim for automated tests
- CI/CD integration
- Regression testing

## Performance Considerations

### Optimization Strategies

1. **Debouncing**:
   - TextChanged events are debounced (500ms default)
   - Prevents excessive processing during typing

2. **Buffer Caching**:
   - Track known links per buffer
   - Only process NEW links, not all links

3. **Lazy Loading**:
   - Plugin only loads for markdown files (ft=markdown)
   - Modules loaded on-demand

4. **File I/O**:
   - Read target file only once
   - Use atomic writes to prevent corruption
   - Batch multiple backlinks if possible

5. **Event Filtering**:
   - Only attach to markdown buffers
   - Detach when buffer is closed

## Design Decisions

### Why Event-Driven vs Filesystem Scanning?

**Event-Driven (Chosen)**:
- Pros: Fast, real-time, minimal overhead
- Cons: Only detects links as they're created

**Filesystem Scanning (Rejected)**:
- Pros: Can find all existing links
- Cons: Slow, resource-intensive, not real-time

**Decision**: Event-driven approach is better for user experience. Users can run manual command to scan existing files if needed.

### Why Plugin-Agnostic?

All markdown plugins (marksman, obsidian.nvim, mkdnflow) insert text into NeoVim buffers normally. They all trigger the same core buffer events. No need for plugin-specific hooks.

### Why "## Backlinks" Section?

- Standard convention from Obsidian/Roam
- Easy to parse (heading level 2)
- Human-readable and editable
- Can be customized via config

### Why Markdown AND Wiki Links?

Different users prefer different formats:
- Markdown links: `[text](path)` - more explicit
- Wiki links: `[[path]]` - cleaner, Obsidian-style

Support both for maximum compatibility.

## Security Considerations

1. **File Permissions**: Check write permissions before modifying files
2. **Path Traversal**: Validate paths to prevent writing outside workspace
3. **Symlinks**: Handle symlinks carefully to avoid infinite loops
4. **Arbitrary Code**: Never eval() user input or file content

## Future Enhancements

### Planned Features
- [ ] Bidirectional link removal (when link is deleted)
- [ ] Orphaned link detection and cleanup
- [ ] Custom backlink section names
- [ ] Multiple backlink sections
- [ ] Link aliases support
- [ ] Performance dashboard

### Potential Integrations
- Graph view (via external tools)
- Telescope picker for backlinks
- LSP integration for link intelligence

## Changelog

### v0.1.0 (In Development)
- Initial implementation
- Basic link detection (markdown + wiki)
- Automatic backlink creation
- Configuration system
- Manual commands

---

Last Updated: 2025-11-01
