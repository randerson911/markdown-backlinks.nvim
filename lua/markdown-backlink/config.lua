-- Configuration management for markdown-backlink.nvim

local M = {}

-- Default configuration
M.defaults = {
  -- Enable automatic backlink creation
  auto_create = true,

  -- Backlinks section header (must be heading level 2)
  backlinks_header = "## Backlinks",

  -- Link format for backlinks: "markdown" or "wiki"
  -- markdown: [Filename](path/to/file.md)
  -- wiki: [[path/to/file]]
  link_format = "markdown",

  -- Show notification when backlink is created
  notify = true,

  -- Only create backlinks for files within the same workspace
  -- (prevents linking to files outside your notes directory)
  workspace_only = true,

  -- Debounce time for text changes (in milliseconds)
  debounce_ms = 500,
}

-- Current configuration (will be merged with user config)
M.options = vim.deepcopy(M.defaults)

-- Setup configuration with user options
---@param opts table|nil User configuration options
function M.setup(opts)
  opts = opts or {}

  -- Merge user options with defaults
  M.options = vim.tbl_deep_extend("force", M.defaults, opts)

  -- Validate configuration
  M.validate()
end

-- Validate configuration options
function M.validate()
  -- Validate link_format
  if M.options.link_format ~= "markdown" and M.options.link_format ~= "wiki" then
    vim.notify(
      "markdown-backlink: Invalid link_format '" .. M.options.link_format .. "'. Using 'markdown'.",
      vim.log.levels.WARN
    )
    M.options.link_format = "markdown"
  end

  -- Validate debounce_ms
  if type(M.options.debounce_ms) ~= "number" or M.options.debounce_ms < 0 then
    vim.notify(
      "markdown-backlink: Invalid debounce_ms. Using default 500ms.",
      vim.log.levels.WARN
    )
    M.options.debounce_ms = 500
  end

  -- Validate backlinks_header starts with ##
  if not M.options.backlinks_header:match("^##%s") then
    vim.notify(
      "markdown-backlink: backlinks_header must start with '## '. Using default.",
      vim.log.levels.WARN
    )
    M.options.backlinks_header = M.defaults.backlinks_header
  end
end

-- Get current configuration
---@return table Current configuration
function M.get()
  return M.options
end

-- Get specific configuration value
---@param key string Configuration key
---@return any Configuration value
function M.get_value(key)
  return M.options[key]
end

-- Set specific configuration value at runtime
---@param key string Configuration key
---@param value any New value
function M.set_value(key, value)
  M.options[key] = value
end

return M
