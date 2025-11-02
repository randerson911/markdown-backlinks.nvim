-- Event handling for markdown-backlinks.nvim
-- Listens to buffer events and triggers backlink creation

local link_detector = require("markdown-backlinks.link_detector")
local path_resolver = require("markdown-backlinks.path_resolver")
local backlink_manager = require("markdown-backlinks.backlink_manager")
local utils = require("markdown-backlinks.utils")
local config = require("markdown-backlinks.config")

local M = {}

-- Buffer cache to track known links
M._buffer_cache = {}

-- Debounce timers per buffer
M._debounce_timers = {}

-- Setup event listeners
function M.setup()
  -- Create autocommand group
  local group = vim.api.nvim_create_augroup("MarkdownBacklink", { clear = true })

  -- Listen to buffer events for markdown files
  vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
    group = group,
    pattern = "*.md",
    callback = function(args)
      M._on_buffer_change(args.buf)
    end,
  })

  -- Also check on buffer save
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*.md",
    callback = function(args)
      M._on_buffer_change(args.buf, true) -- Skip debounce on save
    end,
  })

  -- Auto-scan on buffer open (if enabled)
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    pattern = "*.md",
    callback = function(args)
      M._on_buffer_open(args.buf)
    end,
  })

  -- Clean up cache when buffer is deleted
  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    pattern = "*.md",
    callback = function(args)
      M._buffer_cache[args.buf] = nil
      if M._debounce_timers[args.buf] then
        M._debounce_timers[args.buf]:stop()
        M._debounce_timers[args.buf] = nil
      end
    end,
  })
end

-- Handle buffer change event
---@param bufnr number Buffer number
---@param skip_debounce boolean|nil Skip debouncing (for save events)
function M._on_buffer_change(bufnr, skip_debounce)
  -- Check if plugin is enabled
  local plugin = require("markdown-backlinks")
  if not plugin.is_enabled() then
    return
  end

  -- Debounce for performance
  if not skip_debounce then
    local debounce_ms = config.get_value("debounce_ms")

    -- Cancel existing timer
    if M._debounce_timers[bufnr] then
      M._debounce_timers[bufnr]:stop()
    end

    -- Create new timer
    M._debounce_timers[bufnr] = vim.defer_fn(function()
      M._debounce_timers[bufnr] = nil
      M.process_buffer(bufnr)
    end, debounce_ms)
  else
    -- Process immediately
    M.process_buffer(bufnr)
  end
end

-- Process buffer for new links
---@param bufnr number Buffer number
function M.process_buffer(bufnr)
  -- Ensure buffer is valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Get current file path
  local current_file = vim.api.nvim_buf_get_name(bufnr)

  if current_file == "" or not current_file:match("%.md$") then
    return
  end

  -- Get buffer content
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content_hash = utils.hash_content(lines)

  -- Check if buffer has changed since last check
  local cache = M._buffer_cache[bufnr]
  if cache and cache.content_hash == content_hash then
    -- No changes, skip processing
    return
  end

  -- Find all links in buffer
  local links = link_detector.find_links_in_buffer(bufnr)

  -- Get known links from cache
  local known_links = cache and cache.known_links or {}

  -- Find new links
  local new_links = M._find_new_links(links, known_links)

  if #new_links > 0 then
    -- Process new links
    M._process_new_links(current_file, new_links)

    -- Update cache
    M._update_cache(bufnr, content_hash, links)
  else
    -- Update cache even if no new links (content changed but no new links)
    M._update_cache(bufnr, content_hash, links)
  end
end

-- Find links that weren't in the cache
---@param current_links table[] All current links
---@param known_link_targets string[] Previously known link targets
---@return table[] New links
function M._find_new_links(current_links, known_link_targets)
  local new_links = {}

  for _, link in ipairs(current_links) do
    -- Check if this link target was already known
    local is_known = false
    for _, known_target in ipairs(known_link_targets) do
      if link.target == known_target then
        is_known = true
        break
      end
    end

    if not is_known then
      table.insert(new_links, link)
    end
  end

  return new_links
end

-- Process new links and create backlinks
---@param current_file string Absolute path to current file
---@param links table[] New links to process
function M._process_new_links(current_file, links)
  local workspace_only = config.get_value("workspace_only")

  for _, link in ipairs(links) do
    -- Resolve target path
    local target_path = path_resolver.resolve_link_path(current_file, link.target)

    if target_path then
      -- Check workspace constraint
      if workspace_only then
        if not path_resolver.is_in_same_workspace(current_file, target_path) then
          -- Skip links outside workspace
          goto continue
        end
      end

      -- Ensure backlink exists
      backlink_manager.ensure_backlink(target_path, current_file)
    end

    ::continue::
  end
end

-- Update buffer cache
---@param bufnr number Buffer number
---@param content_hash string Hash of buffer content
---@param links table[] Current links in buffer
function M._update_cache(bufnr, content_hash, links)
  -- Extract link targets
  local link_targets = {}
  for _, link in ipairs(links) do
    table.insert(link_targets, link.target)
  end

  M._buffer_cache[bufnr] = {
    content_hash = content_hash,
    known_links = link_targets,
    last_check = vim.fn.localtime(),
  }
end

-- Handle buffer open event (auto-scan for dead links)
---@param bufnr number Buffer number
function M._on_buffer_open(bufnr)
  -- Check if scan_on_open is enabled
  if not config.get_value("scan_on_open") then
    return
  end

  -- Ensure buffer is valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Get current file path
  local current_file = vim.api.nvim_buf_get_name(bufnr)

  if current_file == "" or not current_file:match("%.md$") then
    return
  end

  -- Defer scan to not block buffer loading
  vim.defer_fn(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    local backlink_finder = require("markdown-backlinks.backlink_finder")

    -- Find dead links in this buffer
    local dead_links = backlink_finder.find_dead_links_in_file(current_file)

    if #dead_links > 0 and config.get_value("scan_notify") then
      local filename = utils.get_filename(current_file)
      utils.notify(
        string.format("%s has %d dead link(s). Use :MarkdownBacklinkDeadLinks to see them.", filename, #dead_links),
        vim.log.levels.WARN
      )
    end
  end, 100) -- Small delay to not interfere with buffer loading
end

return M
