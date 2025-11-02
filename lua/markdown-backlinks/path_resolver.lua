-- Path resolution for markdown links
-- Resolves relative paths to absolute paths

local utils = require("markdown-backlinks.utils")

local M = {}

-- Resolve a link path relative to current file
---@param current_file string Absolute path to current file
---@param link_target string Link target (relative or absolute path)
---@return string|nil Absolute path to target file, or nil if not found
function M.resolve_link_path(current_file, link_target)
  -- Handle empty or invalid inputs
  if not current_file or current_file == "" then
    return nil
  end

  if not link_target or link_target == "" then
    return nil
  end

  -- Remove any anchor/fragment from link (#heading)
  link_target = link_target:gsub("#.*$", "")

  -- Remove any query parameters (?query)
  link_target = link_target:gsub("%?.*$", "")

  -- Trim whitespace
  link_target = vim.trim(link_target)

  if link_target == "" then
    return nil
  end

  -- Ensure .md extension
  link_target = utils.ensure_md_extension(link_target)

  -- If link is absolute, use it directly
  if link_target:sub(1, 1) == "/" then
    if utils.file_exists(link_target) then
      return link_target
    end
    return nil
  end

  -- Resolve relative to current file's directory
  local target_path = utils.normalize_path(link_target, current_file)

  -- Check if resolved file exists
  if utils.file_exists(target_path) then
    return target_path
  end

  -- If file doesn't exist, return nil
  return nil
end

-- Check if link target is within workspace
---@param current_file string Absolute path to current file
---@param target_file string Absolute path to target file
---@return boolean True if both files are in same workspace
function M.is_in_same_workspace(current_file, target_file)
  -- Get current working directory as workspace root
  local cwd = vim.fn.getcwd()

  -- Check if both files are under cwd
  local current_in_workspace = current_file:sub(1, #cwd) == cwd
  local target_in_workspace = target_file:sub(1, #cwd) == cwd

  return current_in_workspace and target_in_workspace
end

-- Get the relative path for creating a backlink
---@param source_file string File that should receive the backlink
---@param target_file string File that contains the original link
---@return string Relative path from source to target
function M.get_backlink_path(source_file, target_file)
  return utils.get_relative_path(source_file, target_file)
end

return M
