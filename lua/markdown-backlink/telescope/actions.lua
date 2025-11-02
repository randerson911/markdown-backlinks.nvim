-- Custom Telescope actions for markdown-backlink.nvim

local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
  error("This module requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)")
end

local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local M = {}

--- Open selected entry in vertical split
---@param prompt_bufnr number Telescope prompt buffer number
function M.open_vsplit(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  if not selection then
    return
  end

  actions.close(prompt_bufnr)
  vim.cmd("vsplit " .. selection.filename)

  if selection.lnum then
    vim.api.nvim_win_set_cursor(0, { selection.lnum, selection.col or 0 })
  end
end

--- Open selected entry in horizontal split
---@param prompt_bufnr number Telescope prompt buffer number
function M.open_split(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  if not selection then
    return
  end

  actions.close(prompt_bufnr)
  vim.cmd("split " .. selection.filename)

  if selection.lnum then
    vim.api.nvim_win_set_cursor(0, { selection.lnum, selection.col or 0 })
  end
end

--- Open selected entry in new tab
---@param prompt_bufnr number Telescope prompt buffer number
function M.open_tab(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  if not selection then
    return
  end

  actions.close(prompt_bufnr)
  vim.cmd("tabnew " .. selection.filename)

  if selection.lnum then
    vim.api.nvim_win_set_cursor(0, { selection.lnum, selection.col or 0 })
  end
end

--- Create backlink from current file to selected entry
---@param prompt_bufnr number Telescope prompt buffer number
function M.create_backlink(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  if not selection then
    return
  end

  local backlink_manager = require("markdown-backlink.backlink_manager")
  local utils = require("markdown-backlink.utils")
  local current_file = vim.api.nvim_buf_get_name(0)

  -- Create backlink in selected file pointing back to current file
  local success = backlink_manager.ensure_backlink(selection.filename, current_file)

  if success then
    utils.notify("Backlink created in " .. utils.get_filename(selection.filename))
  else
    utils.notify("Backlink already exists", vim.log.levels.INFO)
  end

  -- Don't close picker, allow creating multiple backlinks
end

--- Yank the path of selected entry to clipboard
---@param prompt_bufnr number Telescope prompt buffer number
function M.yank_path(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  if not selection then
    return
  end

  local utils = require("markdown-backlink.utils")
  local relative_path = vim.fn.fnamemodify(selection.filename, ":~:.")

  -- Copy to clipboard
  vim.fn.setreg("+", relative_path)
  vim.fn.setreg('"', relative_path)

  utils.notify("Yanked: " .. relative_path)

  -- Don't close picker
end

--- Yank markdown link to selected entry
---@param prompt_bufnr number Telescope prompt buffer number
function M.yank_markdown_link(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  if not selection then
    return
  end

  local utils = require("markdown-backlink.utils")
  local path_resolver = require("markdown-backlink.path_resolver")
  local current_file = vim.api.nvim_buf_get_name(0)

  -- Get relative path from current file to selected file
  local relative_path = path_resolver.get_backlink_path(current_file, selection.filename)
  local filename = utils.get_filename_no_ext(selection.filename)

  -- Format as markdown link
  local markdown_link = string.format("[%s](%s)", filename, relative_path)

  -- Copy to clipboard
  vim.fn.setreg("+", markdown_link)
  vim.fn.setreg('"', markdown_link)

  utils.notify("Yanked: " .. markdown_link)

  -- Don't close picker
end

--- Delete selected orphaned file (with confirmation)
---@param prompt_bufnr number Telescope prompt buffer number
function M.delete_orphan(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  if not selection then
    return
  end

  local utils = require("markdown-backlink.utils")
  local filename = utils.get_filename(selection.filename)

  -- Ask for confirmation
  local confirm = vim.fn.confirm(
    string.format('Delete orphaned file "%s"?', filename),
    "&Yes\n&No",
    2  -- Default to No
  )

  if confirm == 1 then
    -- Delete the file
    local success = pcall(vim.fn.delete, selection.filename)

    if success then
      utils.notify("Deleted: " .. filename)

      -- Refresh the picker by removing from results
      local current_picker = action_state.get_current_picker(prompt_bufnr)
      current_picker:delete_selection(function(sel)
        return sel.filename == selection.filename
      end)
    else
      utils.notify("Failed to delete file", vim.log.levels.ERROR)
    end
  end
end

--- Fix dead link interactively
---@param prompt_bufnr number Telescope prompt buffer number
function M.fix_dead_link(prompt_bufnr)
  local selection = action_state.get_selected_entry()
  if not selection then
    return
  end

  local utils = require("markdown-backlink.utils")

  -- Close picker first
  actions.close(prompt_bufnr)

  -- Open the file with the dead link
  vim.cmd("edit " .. selection.filename)
  vim.api.nvim_win_set_cursor(0, { selection.lnum, 0 })

  -- Highlight the dead link (optional, nice UX)
  vim.cmd("normal! zz")  -- Center cursor

  utils.notify("Fix the dead link manually, or use :MarkdownBacklinkCreate to update backlinks", vim.log.levels.INFO)
end

return M
