-- Telescope extension for markdown-backlink.nvim
-- Registers pickers with :Telescope markdown_backlink <picker>

local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then
  error("This extension requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)")
end

local has_plugin, markdown_backlink_telescope = pcall(require, "markdown-backlink.telescope")

if not has_plugin then
  error("markdown-backlink.nvim telescope module not found")
end

return telescope.register_extension({
  setup = function(ext_config, config)
    -- Extension configuration
    -- Users can pass config via telescope.extensions.markdown_backlink
    -- We don't have any custom config yet, but this is where it would go
  end,

  exports = {
    -- Export all pickers
    backlinks = markdown_backlink_telescope.pickers.backlinks,
    orphans = markdown_backlink_telescope.pickers.orphans,
    dead_links = markdown_backlink_telescope.pickers.dead_links,

    -- Alias for convenience
    list = markdown_backlink_telescope.pickers.backlinks,
  },
})
