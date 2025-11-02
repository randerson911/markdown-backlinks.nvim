-- Telescope pickers for markdown-backlink.nvim

local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
  error("This module requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)")
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local entry_display = require("telescope.pickers.entry_display")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local M = {}

-- Helper: Create displayer for backlinks
local function create_backlink_displayer()
  return entry_display.create({
    separator = " │ ",
    items = {
      { width = 30 },  -- Filename
      { width = 8 },   -- Line number
      { remaining = true },  -- Context
    },
  })
end

-- Helper: Create displayer for orphans
local function create_orphan_displayer()
  return entry_display.create({
    separator = " │ ",
    items = {
      { width = 50 },  -- Filename
      { remaining = true },  -- Reason
    },
  })
end

-- Helper: Create displayer for dead links
local function create_dead_link_displayer()
  return entry_display.create({
    separator = " │ ",
    items = {
      { width = 30 },  -- Source file
      { width = 8 },   -- Line number
      { remaining = true },  -- Dead link target
    },
  })
end

-- Helper: Get relative path for display
local function get_display_path(filepath)
  local cwd = vim.fn.getcwd()
  local relative = filepath:gsub("^" .. vim.pesc(cwd) .. "/", "")
  return relative
end

--- Backlinks picker
--- Shows all files that link to the current file
---@param opts table|nil Telescope options
function M.backlinks(opts)
  opts = opts or {}

  local backlink_finder = require("markdown-backlink.backlink_finder")
  local utils = require("markdown-backlink.utils")
  local current_file = vim.api.nvim_buf_get_name(0)

  if current_file == "" or not current_file:match("%.md$") then
    vim.notify("markdown-backlink: Not a markdown file", vim.log.levels.WARN)
    return
  end

  -- Get backlinks
  local backlinks = backlink_finder.find_backlinks_to_file(current_file)

  if #backlinks == 0 then
    utils.notify("No backlinks found to current file", vim.log.levels.INFO)
    return
  end

  -- Create entry maker
  local displayer = create_backlink_displayer()

  local make_entry = function(backlink)
    local display_path = get_display_path(backlink.file)

    return {
      value = backlink,
      display = function(entry)
        return displayer({
          display_path,
          string.format(":%d", entry.value.line_num),
          vim.trim(entry.value.context),
        })
      end,
      ordinal = display_path .. " " .. backlink.context,
      filename = backlink.file,
      lnum = backlink.line_num,
      col = 1,
    }
  end

  -- Create picker
  pickers.new(opts, {
    prompt_title = "Backlinks to " .. utils.get_filename(current_file),
    finder = finders.new_table({
      results = backlinks,
      entry_maker = make_entry,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = conf.file_previewer(opts),
    attach_mappings = function(prompt_bufnr, map)
      -- Default action: open file at line
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        vim.cmd("edit " .. selection.filename)
        vim.api.nvim_win_set_cursor(0, { selection.lnum, 0 })
      end)

      -- Custom mappings from actions module
      local custom_actions = require("markdown-backlink.telescope.actions")
      map("i", "<C-v>", custom_actions.open_vsplit)
      map("n", "<C-v>", custom_actions.open_vsplit)
      map("i", "<C-s>", custom_actions.open_split)
      map("n", "<C-s>", custom_actions.open_split)
      map("i", "<C-t>", custom_actions.open_tab)
      map("n", "<C-t>", custom_actions.open_tab)

      return true
    end,
  }):find()
end

--- Orphans picker
--- Shows all markdown files with no backlinks
---@param opts table|nil Telescope options
function M.orphans(opts)
  opts = opts or {}

  local backlink_finder = require("markdown-backlink.backlink_finder")
  local utils = require("markdown-backlink.utils")

  utils.notify("Searching for orphaned notes...")

  -- Get orphaned files
  local orphans = backlink_finder.find_orphaned_files()

  if #orphans == 0 then
    utils.notify("No orphaned notes found! All notes have backlinks.", vim.log.levels.INFO)
    return
  end

  -- Create entry maker
  local displayer = create_orphan_displayer()

  local make_entry = function(orphan)
    local display_path = get_display_path(orphan.file)

    return {
      value = orphan,
      display = function(entry)
        return displayer({
          display_path,
          entry.value.reason,
        })
      end,
      ordinal = display_path,
      filename = orphan.file,
      lnum = 1,
      col = 1,
    }
  end

  -- Create picker
  pickers.new(opts, {
    prompt_title = string.format("Orphaned Notes (%d found)", #orphans),
    finder = finders.new_table({
      results = orphans,
      entry_maker = make_entry,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = conf.file_previewer(opts),
    attach_mappings = function(prompt_bufnr, map)
      -- Default action: open file
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        vim.cmd("edit " .. selection.filename)
      end)

      -- Custom mappings
      local custom_actions = require("markdown-backlink.telescope.actions")
      map("i", "<C-v>", custom_actions.open_vsplit)
      map("n", "<C-v>", custom_actions.open_vsplit)
      map("i", "<C-s>", custom_actions.open_split)
      map("n", "<C-s>", custom_actions.open_split)
      map("i", "<C-t>", custom_actions.open_tab)
      map("n", "<C-t>", custom_actions.open_tab)

      return true
    end,
  }):find()
end

--- Dead links picker
--- Shows all broken links in workspace or current file
---@param opts table|nil Telescope options with optional `all` field
function M.dead_links(opts)
  opts = opts or {}

  local backlink_finder = require("markdown-backlink.backlink_finder")
  local utils = require("markdown-backlink.utils")

  local check_all = opts.all or false
  local dead_links

  if check_all then
    utils.notify("Searching for dead links in workspace...")
    dead_links = backlink_finder.find_all_dead_links()
  else
    local current_file = vim.api.nvim_buf_get_name(0)

    if current_file == "" or not current_file:match("%.md$") then
      vim.notify("markdown-backlink: Not a markdown file", vim.log.levels.WARN)
      return
    end

    utils.notify("Checking for dead links in current file...")

    local dead_links_in_file = backlink_finder.find_dead_links_in_file(current_file)

    -- Wrap in file context
    dead_links = {}
    for _, link in ipairs(dead_links_in_file) do
      table.insert(dead_links, {
        file = current_file,
        target = link.target,
        line_num = link.line_num,
        text = link.text,
      })
    end
  end

  if #dead_links == 0 then
    local scope = check_all and "workspace" or "current file"
    utils.notify("No dead links found in " .. scope .. "!", vim.log.levels.INFO)
    return
  end

  -- Create entry maker
  local displayer = create_dead_link_displayer()

  local make_entry = function(dead_link)
    local display_path = get_display_path(dead_link.file)

    return {
      value = dead_link,
      display = function(entry)
        return displayer({
          display_path,
          string.format(":%d", entry.value.line_num),
          string.format('"%s" → %s', entry.value.text, entry.value.target),
        })
      end,
      ordinal = display_path .. " " .. dead_link.target,
      filename = dead_link.file,
      lnum = dead_link.line_num,
      col = 1,
    }
  end

  -- Create picker
  local scope = check_all and "Workspace" or "Current File"
  pickers.new(opts, {
    prompt_title = string.format("Dead Links in %s (%d found)", scope, #dead_links),
    finder = finders.new_table({
      results = dead_links,
      entry_maker = make_entry,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = conf.file_previewer(opts),
    attach_mappings = function(prompt_bufnr, map)
      -- Default action: jump to dead link
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        vim.cmd("edit " .. selection.filename)
        vim.api.nvim_win_set_cursor(0, { selection.lnum, 0 })
      end)

      -- Custom mappings
      local custom_actions = require("markdown-backlink.telescope.actions")
      map("i", "<C-v>", custom_actions.open_vsplit)
      map("n", "<C-v>", custom_actions.open_vsplit)
      map("i", "<C-s>", custom_actions.open_split)
      map("n", "<C-s>", custom_actions.open_split)
      map("i", "<C-t>", custom_actions.open_tab)
      map("n", "<C-t>", custom_actions.open_tab)

      return true
    end,
  }):find()
end

return M
