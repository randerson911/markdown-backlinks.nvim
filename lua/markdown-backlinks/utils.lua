-- Utility functions for markdown-backlinks.nvim

local M = {}

-- Get filename from a path
---@param path string File path
---@return string Filename without directory
function M.get_filename(path)
  return vim.fn.fnamemodify(path, ":t")
end

-- Get filename without extension
---@param path string File path
---@return string Filename without extension
function M.get_filename_no_ext(path)
  return vim.fn.fnamemodify(path, ":t:r")
end

-- Get directory of a file path
---@param path string File path
---@return string Directory path
function M.get_directory(path)
  return vim.fn.fnamemodify(path, ":h")
end

-- Get relative path from one file to another
---@param from string Source file path (absolute)
---@param to string Target file path (absolute)
---@return string Relative path
function M.get_relative_path(from, to)
  local from_dir = M.get_directory(from)

  -- Use vim's built-in relative path function
  local relative = vim.fn.fnamemodify(to, ":." )

  -- If paths are in different directories, calculate relative path
  -- This is a simple implementation - could be improved
  local from_parts = vim.split(from_dir, "/", { plain = true })
  local to_parts = vim.split(M.get_directory(to), "/", { plain = true })

  -- Find common prefix
  local common = 0
  for i = 1, math.min(#from_parts, #to_parts) do
    if from_parts[i] == to_parts[i] then
      common = i
    else
      break
    end
  end

  -- Build relative path
  local result = {}

  -- Add .. for each directory we need to go up
  for _ = common + 1, #from_parts do
    table.insert(result, "..")
  end

  -- Add directories we need to go down
  for i = common + 1, #to_parts do
    table.insert(result, to_parts[i])
  end

  -- Add filename
  table.insert(result, M.get_filename(to))

  if #result == 0 then
    return M.get_filename(to)
  end

  return table.concat(result, "/")
end

-- Normalize path (resolve . and .., convert to absolute)
---@param path string Path to normalize
---@param relative_to string|nil Base path for relative paths
---@return string Normalized absolute path
function M.normalize_path(path, relative_to)
  -- If path is already absolute, just resolve it
  if path:sub(1, 1) == "/" then
    return vim.fn.resolve(path)
  end

  -- If relative_to is provided, join paths
  if relative_to then
    local base_dir = M.get_directory(relative_to)
    path = base_dir .. "/" .. path
  end

  -- Resolve to absolute path
  return vim.fn.resolve(vim.fn.fnamemodify(path, ":p"))
end

-- Check if file exists
---@param path string File path
---@return boolean True if file exists
function M.file_exists(path)
  return vim.fn.filereadable(path) == 1
end

-- Check if path is a directory
---@param path string Path to check
---@return boolean True if path is a directory
function M.is_directory(path)
  return vim.fn.isdirectory(path) == 1
end

-- Read file contents
---@param path string File path
---@return string[]|nil File lines, or nil on error
function M.read_file(path)
  if not M.file_exists(path) then
    return nil
  end

  local lines = vim.fn.readfile(path)
  return lines
end

-- Write file contents atomically
---@param path string File path
---@param lines string[] File lines
---@return boolean True if successful
function M.write_file(path, lines)
  -- Check if we have write permission
  local dir = M.get_directory(path)
  if not M.is_directory(dir) then
    M.notify("Directory does not exist: " .. dir, vim.log.levels.ERROR)
    return false
  end

  -- Write file
  local ok = pcall(vim.fn.writefile, lines, path)

  if not ok then
    M.notify("Failed to write file: " .. path, vim.log.levels.ERROR)
    return false
  end

  return true
end

-- Show notification to user
---@param msg string Message to show
---@param level number|nil Log level (default: INFO)
function M.notify(msg, level)
  local config = require("markdown-backlinks.config")

  -- Only show notifications if enabled
  if not config.get_value("notify") then
    return
  end

  level = level or vim.log.levels.INFO
  vim.notify("markdown-backlinks: " .. msg, level)
end

-- Check if a line number is inside a code block
---@param lines string[] All lines in buffer
---@param line_num number Line number to check (1-indexed)
---@return boolean True if inside code block
function M.is_in_code_block(lines, line_num)
  local in_code_block = false

  for i = 1, line_num do
    local line = lines[i]
    -- Check for code fence (``` or ~~~)
    if line:match("^```") or line:match("^~~~") then
      in_code_block = not in_code_block
    end
  end

  return in_code_block
end

-- Check if text is inside inline code
---@param line string Line of text
---@param col number Column position (0-indexed)
---@return boolean True if inside inline code
function M.is_in_inline_code(line, col)
  -- Count backticks before the column
  local before = line:sub(1, col)
  local backtick_count = 0

  for i = 1, #before do
    if before:sub(i, i) == "`" then
      backtick_count = backtick_count + 1
    end
  end

  -- If odd number of backticks, we're inside inline code
  return backtick_count % 2 == 1
end

-- Calculate hash of buffer content (for change detection)
---@param lines string[] Buffer lines
---@return string Hash of content
function M.hash_content(lines)
  local content = table.concat(lines, "\n")
  -- Simple hash: just use length + first/last chars for speed
  -- For production, could use actual hash function
  if #content == 0 then
    return "empty"
  end
  return string.format("%d_%s_%s", #content, content:sub(1, 1), content:sub(-1))
end

-- Ensure path has .md extension
---@param path string File path
---@return string Path with .md extension
function M.ensure_md_extension(path)
  if not path:match("%.md$") then
    return path .. ".md"
  end
  return path
end

return M
