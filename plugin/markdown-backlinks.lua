-- Plugin registration for markdown-backlinks.nvim
-- This file is automatically sourced by NeoVim

-- Prevent loading twice
if vim.g.loaded_markdown_backlinks then
  return
end
vim.g.loaded_markdown_backlinks = 1

-- The plugin will be initialized when user calls setup() in their config
-- No automatic initialization here - let user control it
