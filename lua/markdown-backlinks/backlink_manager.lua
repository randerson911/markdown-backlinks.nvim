-- Backlink management
-- Detects and inserts backlinks in markdown files

local utils = require("markdown-backlinks.utils")
local path_resolver = require("markdown-backlinks.path_resolver")
local config = require("markdown-backlinks.config")

local M = {}

-- Check if target file has a backlink to source file
---@param target_file string Absolute path to file that should have backlink
---@param source_file string Absolute path to file that created the link
---@return boolean True if backlink exists
function M.has_backlink(target_file, source_file)
  local lines = utils.read_file(target_file)
  if not lines then
    return false
  end

  -- Get relative path for the backlink
  local backlink_path = path_resolver.get_backlink_path(target_file, source_file)

  -- Check if backlink exists in any form
  for _, line in ipairs(lines) do
    -- Check for markdown link: [text](path)
    if line:find("%[.-%]%(.-" .. vim.pesc(backlink_path) .. ".-%)", 1, false) then
      return true
    end

    -- Check for wiki link: [[path]]
    local wiki_path = backlink_path:gsub("%.md$", "")
    if line:find("%[%[.-" .. vim.pesc(wiki_path) .. ".-%]%]", 1, false) then
      return true
    end
  end

  return false
end

-- Ensure backlink exists in target file (create if missing)
---@param target_file string File that should have backlink
---@param source_file string File that created the original link
---@return boolean True if backlink was added, false if it already existed
function M.ensure_backlink(target_file, source_file)
  -- Check if backlink already exists
  if M.has_backlink(target_file, source_file) then
    return false
  end

  -- Read target file
  local lines = utils.read_file(target_file)
  if not lines then
    utils.notify("Cannot read target file: " .. target_file, vim.log.levels.ERROR)
    return false
  end

  -- Find or create backlinks section
  local section_line = M._find_backlinks_section(lines)
  local backlinks_header = config.get_value("backlinks_header")

  if not section_line then
    -- Create new backlinks section at end of file
    if #lines > 0 and lines[#lines] ~= "" then
      table.insert(lines, "")
    end
    table.insert(lines, backlinks_header)
    table.insert(lines, "")
    section_line = #lines - 1
  end

  -- Format backlink
  local backlink = M._format_backlink(target_file, source_file)

  -- Insert backlink after section header
  table.insert(lines, section_line + 1, backlink)

  -- Write file
  if utils.write_file(target_file, lines) then
    local source_name = utils.get_filename_no_ext(source_file)
    utils.notify("Added backlink in " .. utils.get_filename(target_file))
    return true
  end

  return false
end

-- Find the line number of the backlinks section
---@param lines string[] File lines
---@return number|nil Line number (1-indexed) or nil if not found
function M._find_backlinks_section(lines)
  local backlinks_header = config.get_value("backlinks_header")
  local in_code_block = false

  for i, line in ipairs(lines) do
    -- Track code blocks
    if line:match("^```") or line:match("^~~~") then
      in_code_block = not in_code_block
    end

    -- Look for backlinks header outside code blocks
    if not in_code_block and line == backlinks_header then
      return i
    end
  end

  return nil
end

-- Format a backlink according to configuration
---@param target_file string File that will contain the backlink
---@param source_file string File that created the original link
---@return string Formatted backlink line
function M._format_backlink(target_file, source_file)
  local link_format = config.get_value("link_format")
  local relative_path = path_resolver.get_backlink_path(target_file, source_file)
  local source_name = utils.get_filename_no_ext(source_file)

  if link_format == "wiki" then
    -- Wiki format: - [[path]]
    local wiki_path = relative_path:gsub("%.md$", "")
    return "- [[" .. wiki_path .. "]]"
  else
    -- Markdown format: - [Name](path)
    return "- [" .. source_name .. "](" .. relative_path .. ")"
  end
end

return M
