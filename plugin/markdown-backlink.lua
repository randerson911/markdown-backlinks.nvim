-- Plugin registration for markdown-backlink.nvim
-- This file is automatically sourced by NeoVim

-- Prevent loading twice
if vim.g.loaded_markdown_backlink then
  return
end
vim.g.loaded_markdown_backlink = 1

-- The plugin will be initialized when user calls setup() in their config
-- No automatic initialization here - let user control it
