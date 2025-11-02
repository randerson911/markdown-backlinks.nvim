-- Telescope integration for markdown-backlinks.nvim
-- Entry point for telescope functionality

local M = {}

-- Check if telescope is available
M.has_telescope = pcall(require, "telescope")

if not M.has_telescope then
  return M
end

-- Export pickers
M.pickers = require("markdown-backlinks.telescope.pickers")
M.actions = require("markdown-backlinks.telescope.actions")

return M
