# Feature Roadmap - markdown-backlink.nvim

This document outlines potential quality of life features based on user research from similar plugins (obsidian.nvim, mkdnflow.nvim). Features are ranked by implementation complexity and user demand.

## Complexity Scale

- **Easy (1-2)**: Minimal code, uses existing infrastructure
- **Medium (3-5)**: Some new components, moderate complexity
- **Hard (6-8)**: Multiple new systems, external dependencies
- **Very Hard (9-10)**: Major architectural changes, complex integrations

---

## Quick Wins (Easy + High Impact)

### 1. Backlink Viewer ⭐⭐⭐
**Complexity: 2/10** | **Impact: Very High** | **Status: Planned**

Show all backlinks to the current note in a simple list.

**Implementation:**
- Read current file path
- Search all markdown files in workspace for links to current file
- Display results in quickfix list or floating window
- No external dependencies needed

**Command:** `:MarkdownBacklinkList`

**Why Easy:**
- Uses existing `link_detector` and `path_resolver` modules
- Simple file scanning with ripgrep or built-in search
- No UI dependencies (use native quickfix/location list)

---

### 2. Orphaned Note Detection ⭐⭐⭐
**Complexity: 2/10** | **Impact: High** | **Status: Planned**

Find notes that have no backlinks (isolated notes).

**Implementation:**
- Scan workspace for all .md files
- For each file, check if any other file links to it
- Report files with zero backlinks

**Command:** `:MarkdownBacklinkOrphans`

**Why Easy:**
- Uses existing `backlink_manager.has_backlink()` logic
- Simple iteration over files
- No complex data structures needed

---

### 3. Dead Link Detection ⭐⭐⭐
**Complexity: 2/10** | **Impact: High** | **Status: Planned**

Detect links to non-existent files.

**Implementation:**
- Use existing `link_detector` to find all links in current buffer
- Use `path_resolver` to check if target exists
- Report broken links

**Command:** `:MarkdownBacklinkDeadLinks`

**Why Easy:**
- Reuses existing `link_detector.find_links_in_buffer()`
- Reuses existing `path_resolver.resolve_link_path()`
- Just filters for nil results (file doesn't exist)

---

## Medium Effort Features

### 4. Backlink Context ⭐⭐
**Complexity: 4/10** | **Impact: Medium-High** | **Status: Future**

Show surrounding text when listing backlinks (not just filename).

**Implementation:**
- When finding backlinks, capture N lines before/after the link
- Display in format: `file.md:42: "...surrounding context..."`
- Requires parsing file content around links

**Enhancement to:** `:MarkdownBacklinkList`

**Why Medium:**
- Need to read and parse file content (not just detect links)
- Formatting output nicely requires thought
- Optional Telescope integration for better UX

**Dependencies:**
- None required, but better with Telescope

---

### 5. File Rename with Auto-Update ⭐⭐⭐
**Complexity: 5/10** | **Impact: Very High** | **Status: Future**

Rename a file and automatically update ALL references to it.

**Implementation:**
1. Prompt for new filename
2. Find all files linking to current file
3. Update each link to use new filename
4. Rename the actual file
5. Update buffer names in NeoVim

**Command:** `:MarkdownBacklinkRename <new-name>`

**Why Medium:**
- Need to modify multiple files safely
- Handle relative path updates correctly
- Need transaction-like behavior (rollback on failure)
- Buffer management complexity

**Challenges:**
- What if file is open in multiple buffers?
- Need to handle vim.lsp.util.rename integration?
- Undo/redo across multiple files

---

### 6. Bulk Backlink Sync ⭐
**Complexity: 3/10** | **Impact: Medium** | **Status: Future**

Scan entire workspace and create all missing backlinks at once.

**Implementation:**
- Find all markdown files
- For each file, find all links
- Create missing backlinks for each link
- Report statistics (X backlinks created)

**Command:** `:MarkdownBacklinkSyncAll`

**Why Medium:**
- Potentially slow for large vaults
- Need progress indication for long operations
- Risk of modifying many files at once

**Enhancement:**
- Add `--dry-run` flag to preview changes
- Add confirmation prompt before modifying files

---

## Hard Features

### 7. Telescope/FZF Integration ⭐⭐
**Complexity: 6/10** | **Impact: Medium** | **Status: Future**

Better UI for browsing backlinks with fuzzy finding.

**Implementation:**
- Create Telescope picker for backlinks
- Create FZF-lua picker as alternative
- Support preview of linked notes
- Jump to backlink on selection

**Command:** `:Telescope markdown_backlinks`

**Why Hard:**
- External dependency (Telescope or FZF)
- Need to learn Telescope API
- Multiple picker implementations for different tools
- Preview functionality complexity

**Dependencies:**
- telescope.nvim (optional)
- fzf-lua (optional alternative)

---

### 8. Heading/Anchor Link Support ⭐⭐
**Complexity: 6/10** | **Impact: Medium** | **Status: Future**

Full support for links to specific headings: `[text](file.md#heading)`

**Implementation:**
- Parse headings in markdown files
- Track which headings are linked
- Create backlinks with heading context
- "Go to heading" navigation

**Enhancement to:** All commands

**Why Hard:**
- Need heading parser
- Need to match heading IDs correctly
- Obsidian vs standard markdown heading slugs differ
- Backlink format needs heading reference

**Challenges:**
- Heading slug generation (spaces, special chars)
- What if heading is renamed?
- Multiple headings with same name

---

### 9. LSP Diagnostics Integration ⭐
**Complexity: 7/10** | **Impact: Medium** | **Status: Future**

Show dead links as LSP diagnostics (underline in editor).

**Implementation:**
- Register as LSP provider
- Provide diagnostics for broken links
- Code actions to fix/remove dead links
- Integration with existing LSP ecosystem

**Enhancement to:** Dead link detection

**Why Hard:**
- Need to implement LSP protocol
- Coordinate with marksman LSP (avoid conflicts)
- Diagnostic positioning/ranges
- Code action implementation

**Dependencies:**
- Understanding of NeoVim LSP API
- Potential conflict with marksman

---

## Very Hard Features

### 10. Graph View ⭐
**Complexity: 9/10** | **Impact: Low-Medium** | **Status: Future**

Visual representation of note connections.

**Implementation Option A - DOT Export:**
- Generate GraphViz DOT file
- Open with external tool (xdot, graphviz)

**Implementation Option B - Terminal UI:**
- Use ascii/unicode box drawing
- Interactive terminal graph

**Implementation Option C - Web UI:**
- Generate HTML with D3.js/Mermaid
- Open in browser

**Command:** `:MarkdownBacklinkGraph`

**Why Very Hard:**
- Graph layout algorithms are complex
- Need rendering solution (terminal/web/external)
- Performance with large graphs (100+ notes)
- Interactive features (zoom, pan, filter)

**Best Approach:**
- Start with DOT file export (easiest)
- Let users use existing graph tools

**Dependencies:**
- graphviz (external tool, optional)
- Or web browser for HTML output

---

### 11. Real-time Link Preview ⭐
**Complexity: 8/10** | **Impact: Medium** | **Status: Future**

Hover over link to see preview of target note.

**Implementation:**
- Integrate with vim.lsp.buf.hover()
- Show first N lines of target file
- Markdown rendering in hover window

**Why Very Hard:**
- Need LSP hover implementation
- Coordinate with marksman (avoid duplicate hovers)
- Markdown rendering in popup
- Performance for large files

---

### 12. Tag Support in Backlinks
**Complexity: 7/10** | **Impact: Low** | **Status: Future**

Track and link by tags (#tag).

**Implementation:**
- Parse tags in frontmatter and content
- Create tag index
- Show notes by tag
- Backlinks for tags

**Why Hard:**
- New concept beyond file-to-file links
- Tag parsing (inline vs frontmatter)
- Tag index data structure
- Tag rename support

---

## Feature Priority Matrix

```
High Impact + Easy → IMPLEMENT FIRST ✅
├── Backlink Viewer (2/10)
├── Orphaned Note Detection (2/10)
└── Dead Link Detection (2/10)

High Impact + Medium → IMPLEMENT NEXT
├── File Rename (5/10)
└── Backlink Context (4/10)

Medium Impact + Easy/Medium → NICE TO HAVE
├── Bulk Sync (3/10)
└── Telescope Integration (6/10)

Low-Medium Impact + Hard → LATER
├── Heading Links (6/10)
├── LSP Diagnostics (7/10)
├── Graph View (9/10)
└── Tags (7/10)
```

---

## Implementation Plan

### Phase 1: Quick Wins (Next Release)
- [ ] `:MarkdownBacklinkList` - Show backlinks to current note
- [ ] `:MarkdownBacklinkOrphans` - Find orphaned notes
- [ ] `:MarkdownBacklinkDeadLinks` - Find broken links
- [ ] Auto-scan on buffer open (configurable)

### Phase 2: Enhanced Navigation
- [ ] `:MarkdownBacklinkRename` - Rename file + update refs
- [ ] Backlink context in list view
- [ ] `:MarkdownBacklinkSyncAll` - Bulk backlink creation

### Phase 3: External Integrations
- [ ] Telescope picker for backlinks
- [ ] FZF-lua alternative
- [ ] Graph export (DOT file)

### Phase 4: Advanced Features
- [ ] Heading link support
- [ ] LSP diagnostics
- [ ] Tag support
- [ ] Real-time preview

---

## User Demand Summary

Based on research from obsidian.nvim and mkdnflow.nvim issues:

**Most Requested:**
1. Backlink viewer (seeing "what links here")
2. File rename with auto-update
3. Dead link detection
4. Orphaned note detection

**Frequently Mentioned:**
5. Better link navigation (gf, go back)
6. Alias support
7. Telescope integration
8. Graph view

**Nice to Have:**
9. Tag support
10. LSP integration
11. Heading links
12. Link preview

---

Last Updated: 2025-11-01
