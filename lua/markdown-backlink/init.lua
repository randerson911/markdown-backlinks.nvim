-- markdown-backlink.nvim
-- Automatic bidirectional link management for markdown files

local M = {}

-- Plugin state
M._enabled = true
M._initialized = false

-- Setup plugin with user configuration
---@param opts table|nil User configuration
function M.setup(opts)
  -- Load and setup configuration
  local config = require("markdown-backlink.config")
  config.setup(opts)

  -- Initialize event handlers
  local events = require("markdown-backlink.events")
  events.setup()

  -- Register commands
  M._register_commands()

  M._initialized = true
  M._enabled = config.get_value("auto_create")
end

-- Enable automatic backlink creation
function M.enable()
  M._enabled = true
  require("markdown-backlink.utils").notify("Automatic backlink creation enabled")
end

-- Disable automatic backlink creation
function M.disable()
  M._enabled = false
  require("markdown-backlink.utils").notify("Automatic backlink creation disabled")
end

-- Check if plugin is enabled
---@return boolean True if enabled
function M.is_enabled()
  return M._enabled
end

-- Manually create backlinks for current buffer
function M.create_backlinks()
  if not M._initialized then
    vim.notify("markdown-backlink: Plugin not initialized. Call setup() first.", vim.log.levels.ERROR)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local events = require("markdown-backlink.events")
  events.process_buffer(bufnr)
end

-- Check for missing backlinks in current buffer
function M.check_backlinks()
  if not M._initialized then
    vim.notify("markdown-backlink: Plugin not initialized. Call setup() first.", vim.log.levels.ERROR)
    return
  end

  local link_detector = require("markdown-backlink.link_detector")
  local path_resolver = require("markdown-backlink.path_resolver")
  local backlink_manager = require("markdown-backlink.backlink_manager")

  local bufnr = vim.api.nvim_get_current_buf()
  local current_file = vim.api.nvim_buf_get_name(bufnr)

  if current_file == "" or not current_file:match("%.md$") then
    vim.notify("markdown-backlink: Not a markdown file", vim.log.levels.WARN)
    return
  end

  -- Find all links in current buffer
  local links = link_detector.find_links_in_buffer(bufnr)

  if #links == 0 then
    vim.notify("markdown-backlink: No links found in current buffer", vim.log.levels.INFO)
    return
  end

  -- Check each link for backlinks
  local missing = {}

  for _, link in ipairs(links) do
    local target_path = path_resolver.resolve_link_path(current_file, link.target)

    if target_path then
      local has_backlink = backlink_manager.has_backlink(target_path, current_file)
      if not has_backlink then
        table.insert(missing, {
          target = link.target,
          resolved = target_path,
          line = link.line_num,
        })
      end
    end
  end

  -- Report results
  if #missing == 0 then
    vim.notify("markdown-backlink: All links have backlinks!", vim.log.levels.INFO)
  else
    local msg = string.format("markdown-backlink: %d link(s) missing backlinks:", #missing)
    for _, item in ipairs(missing) do
      msg = msg .. string.format("\n  Line %d: %s", item.line, item.target)
    end
    vim.notify(msg, vim.log.levels.WARN)
  end
end

-- List all backlinks to current file
function M.list_backlinks()
  if not M._initialized then
    vim.notify("markdown-backlink: Plugin not initialized. Call setup() first.", vim.log.levels.ERROR)
    return
  end

  local config = require("markdown-backlink.config")

  -- Try Telescope first if enabled
  if config.get_value("telescope_enabled") then
    local has_telescope, telescope_module = pcall(require, "markdown-backlink.telescope")
    if has_telescope and telescope_module.has_telescope then
      telescope_module.pickers.backlinks()
      return
    end
  end

  -- Fallback to quickfix
  M._list_backlinks_quickfix()
end

-- Quickfix version of list_backlinks (fallback)
function M._list_backlinks_quickfix()
  local backlink_finder = require("markdown-backlink.backlink_finder")
  local utils = require("markdown-backlink.utils")

  local current_file = vim.api.nvim_buf_get_name(0)

  if current_file == "" or not current_file:match("%.md$") then
    vim.notify("markdown-backlink: Not a markdown file", vim.log.levels.WARN)
    return
  end

  utils.notify("Searching for backlinks...")

  -- Find all backlinks to current file
  local backlinks = backlink_finder.find_backlinks_to_file(current_file)

  if #backlinks == 0 then
    utils.notify("No backlinks found to current file", vim.log.levels.INFO)
    return
  end

  -- Format for quickfix list
  local qf_list = backlink_finder.format_backlinks_for_quickfix(backlinks, current_file)

  -- Set quickfix list
  vim.fn.setqflist(qf_list, "r")
  vim.cmd("copen")

  local filename = utils.get_filename(current_file)
  utils.notify(string.format("Found %d backlink(s) to %s", #backlinks, filename))
end

-- Find all orphaned files (files with no backlinks)
function M.find_orphans()
  if not M._initialized then
    vim.notify("markdown-backlink: Plugin not initialized. Call setup() first.", vim.log.levels.ERROR)
    return
  end

  local config = require("markdown-backlink.config")

  -- Try Telescope first if enabled
  if config.get_value("telescope_enabled") then
    local has_telescope, telescope_module = pcall(require, "markdown-backlink.telescope")
    if has_telescope and telescope_module.has_telescope then
      telescope_module.pickers.orphans()
      return
    end
  end

  -- Fallback to quickfix
  M._find_orphans_quickfix()
end

-- Quickfix version of find_orphans (fallback)
function M._find_orphans_quickfix()
  local backlink_finder = require("markdown-backlink.backlink_finder")
  local utils = require("markdown-backlink.utils")

  utils.notify("Searching for orphaned notes...")

  -- Find all orphaned files
  local orphans = backlink_finder.find_orphaned_files()

  if #orphans == 0 then
    utils.notify("No orphaned notes found! All notes have backlinks.", vim.log.levels.INFO)
    return
  end

  -- Format for quickfix list
  local qf_list = backlink_finder.format_orphans_for_quickfix(orphans)

  -- Set quickfix list
  vim.fn.setqflist(qf_list, "r")
  vim.cmd("copen")

  utils.notify(string.format("Found %d orphaned note(s)", #orphans))
end

-- Find all dead links in current buffer or workspace
function M.find_dead_links(args)
  if not M._initialized then
    vim.notify("markdown-backlink: Plugin not initialized. Call setup() first.", vim.log.levels.ERROR)
    return
  end

  local config = require("markdown-backlink.config")
  local check_all = args.args == "all"

  -- Try Telescope first if enabled
  if config.get_value("telescope_enabled") then
    local has_telescope, telescope_module = pcall(require, "markdown-backlink.telescope")
    if has_telescope and telescope_module.has_telescope then
      telescope_module.pickers.dead_links({ all = check_all })
      return
    end
  end

  -- Fallback to quickfix
  M._find_dead_links_quickfix(check_all)
end

-- Quickfix version of find_dead_links (fallback)
function M._find_dead_links_quickfix(check_all)
  local backlink_finder = require("markdown-backlink.backlink_finder")
  local utils = require("markdown-backlink.utils")

  if check_all then
    utils.notify("Searching for dead links in workspace...")

    -- Find all dead links in workspace
    local dead_links = backlink_finder.find_all_dead_links()

    if #dead_links == 0 then
      utils.notify("No dead links found in workspace!", vim.log.levels.INFO)
      return
    end

    -- Format for quickfix list
    local qf_list = backlink_finder.format_dead_links_for_quickfix(dead_links)

    -- Set quickfix list
    vim.fn.setqflist(qf_list, "r")
    vim.cmd("copen")

    utils.notify(string.format("Found %d dead link(s) in workspace", #dead_links))
  else
    -- Check only current buffer
    local current_file = vim.api.nvim_buf_get_name(0)

    if current_file == "" or not current_file:match("%.md$") then
      vim.notify("markdown-backlink: Not a markdown file", vim.log.levels.WARN)
      return
    end

    utils.notify("Checking for dead links in current file...")

    local dead_links = backlink_finder.find_dead_links_in_file(current_file)

    if #dead_links == 0 then
      utils.notify("No dead links found in current file!", vim.log.levels.INFO)
      return
    end

    -- Format for quickfix list (wrap in file context)
    local dead_links_with_file = {}
    for _, link in ipairs(dead_links) do
      table.insert(dead_links_with_file, {
        file = current_file,
        target = link.target,
        line_num = link.line_num,
        text = link.text,
      })
    end

    local qf_list = backlink_finder.format_dead_links_for_quickfix(dead_links_with_file)

    -- Set quickfix list
    vim.fn.setqflist(qf_list, "r")
    vim.cmd("copen")

    utils.notify(string.format("Found %d dead link(s) in current file", #dead_links))
  end
end

-- Register plugin commands
function M._register_commands()
  -- Manual backlink creation
  vim.api.nvim_create_user_command("MarkdownBacklinkCreate", function()
    M.create_backlinks()
  end, {
    desc = "Manually create backlinks for current buffer",
  })

  -- Check for missing backlinks
  vim.api.nvim_create_user_command("MarkdownBacklinkCheck", function()
    M.check_backlinks()
  end, {
    desc = "Check for missing backlinks in current buffer",
  })

  -- List all backlinks to current file
  vim.api.nvim_create_user_command("MarkdownBacklinkList", function()
    M.list_backlinks()
  end, {
    desc = "List all backlinks to current file",
  })

  -- Find orphaned notes
  vim.api.nvim_create_user_command("MarkdownBacklinkOrphans", function()
    M.find_orphans()
  end, {
    desc = "Find all orphaned notes (notes with no backlinks)",
  })

  -- Find dead links
  vim.api.nvim_create_user_command("MarkdownBacklinkDeadLinks", function(args)
    M.find_dead_links(args)
  end, {
    nargs = "?",
    complete = function()
      return { "all" }
    end,
    desc = "Find dead links (use 'all' to check entire workspace)",
  })

  -- Enable auto-creation
  vim.api.nvim_create_user_command("MarkdownBacklinkEnable", function()
    M.enable()
  end, {
    desc = "Enable automatic backlink creation",
  })

  -- Disable auto-creation
  vim.api.nvim_create_user_command("MarkdownBacklinkDisable", function()
    M.disable()
  end, {
    desc = "Disable automatic backlink creation",
  })
end

return M
