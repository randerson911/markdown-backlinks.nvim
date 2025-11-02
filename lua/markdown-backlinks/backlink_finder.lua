-- Backlink finder for advanced features
-- Find backlinks, orphans, and dead links across workspace

local utils = require("markdown-backlinks.utils")
local link_detector = require("markdown-backlinks.link_detector")
local path_resolver = require("markdown-backlinks.path_resolver")

local M = {}

-- Find all markdown files in workspace
---@param workspace_root string|nil Root directory to search (defaults to cwd)
---@return string[] List of absolute paths to .md files
function M.find_all_markdown_files(workspace_root)
  workspace_root = workspace_root or vim.fn.getcwd()

  -- Use vim's globpath for finding files
  local files_string = vim.fn.globpath(workspace_root, "**/*.md", false, false)
  local files = vim.split(files_string, "\n", { trimempty = true })

  -- Convert to absolute paths
  local absolute_files = {}
  for _, file in ipairs(files) do
    if file ~= "" then
      local abs_path = vim.fn.fnamemodify(file, ":p")
      table.insert(absolute_files, abs_path)
    end
  end

  return absolute_files
end

-- Find all files that link to the given file
---@param target_file string Absolute path to file to find backlinks for
---@param workspace_files string[]|nil List of files to search (optional, will scan workspace if nil)
---@return table[] List of backlink objects {file: string, line_num: number, text: string, context: string}
function M.find_backlinks_to_file(target_file, workspace_files)
  workspace_files = workspace_files or M.find_all_markdown_files()

  local backlinks = {}
  local target_filename = utils.get_filename(target_file)

  for _, source_file in ipairs(workspace_files) do
    -- Skip the target file itself
    if source_file ~= target_file then
      local lines = utils.read_file(source_file)

      if lines then
        -- Check each line for links
        for line_num, line in ipairs(lines) do
          -- Use link detector to find all links in this line
          local temp_buf = vim.api.nvim_create_buf(false, true)
          vim.api.nvim_buf_set_lines(temp_buf, 0, -1, false, { line })

          local links = link_detector.find_links_in_buffer(temp_buf)
          vim.api.nvim_buf_delete(temp_buf, { force = true })

          for _, link in ipairs(links) do
            -- Resolve the link path
            local resolved_path = path_resolver.resolve_link_path(source_file, link.target)

            -- Check if this link points to our target file
            if resolved_path == target_file then
              table.insert(backlinks, {
                file = source_file,
                line_num = line_num,
                text = link.text,
                link_target = link.target,
                context = line, -- Full line as context
              })
            end
          end
        end
      end
    end
  end

  return backlinks
end

-- Find all orphaned files (files with no backlinks)
---@param workspace_files string[]|nil List of files to check (optional)
---@return table[] List of orphaned file objects {file: string, reason: string}
function M.find_orphaned_files(workspace_files)
  workspace_files = workspace_files or M.find_all_markdown_files()

  local orphans = {}

  for _, file in ipairs(workspace_files) do
    local backlinks = M.find_backlinks_to_file(file, workspace_files)

    if #backlinks == 0 then
      table.insert(orphans, {
        file = file,
        reason = "No backlinks found",
      })
    end
  end

  return orphans
end

-- Find all dead links in a file
---@param source_file string Absolute path to file to check
---@return table[] List of dead link objects {target: string, line_num: number, resolved_path: string|nil}
function M.find_dead_links_in_file(source_file)
  local dead_links = {}

  -- Read file into a buffer temporarily
  local lines = utils.read_file(source_file)
  if not lines then
    return dead_links
  end

  -- Create temporary buffer to use link detector
  local temp_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(temp_buf, 0, -1, false, lines)

  local links = link_detector.find_links_in_buffer(temp_buf)
  vim.api.nvim_buf_delete(temp_buf, { force = true })

  -- Check each link
  for _, link in ipairs(links) do
    local resolved_path = path_resolver.resolve_link_path(source_file, link.target)

    -- If path couldn't be resolved, it's a dead link
    if not resolved_path then
      table.insert(dead_links, {
        target = link.target,
        line_num = link.line_num,
        resolved_path = nil,
        text = link.text,
      })
    end
  end

  return dead_links
end

-- Find all dead links across workspace
---@param workspace_files string[]|nil List of files to check (optional)
---@return table[] List of dead link objects with file info
function M.find_all_dead_links(workspace_files)
  workspace_files = workspace_files or M.find_all_markdown_files()

  local all_dead_links = {}

  for _, file in ipairs(workspace_files) do
    local dead_links = M.find_dead_links_in_file(file)

    for _, link in ipairs(dead_links) do
      table.insert(all_dead_links, {
        file = file,
        target = link.target,
        line_num = link.line_num,
        text = link.text,
      })
    end
  end

  return all_dead_links
end

-- Format backlinks for display in quickfix list
---@param backlinks table[] List of backlink objects
---@param target_file string The file that was searched for
---@return table[] Quickfix list entries
function M.format_backlinks_for_quickfix(backlinks, target_file)
  local qf_list = {}

  if #backlinks == 0 then
    return qf_list
  end

  for _, backlink in ipairs(backlinks) do
    local filename_rel = vim.fn.fnamemodify(backlink.file, ":~:.")
    local text = string.format('[%s] "%s"', backlink.text, vim.trim(backlink.context))

    table.insert(qf_list, {
      filename = backlink.file,
      lnum = backlink.line_num,
      col = 1,
      text = text,
    })
  end

  return qf_list
end

-- Format orphaned files for display in quickfix list
---@param orphans table[] List of orphan objects
---@return table[] Quickfix list entries
function M.format_orphans_for_quickfix(orphans)
  local qf_list = {}

  for _, orphan in ipairs(orphans) do
    local filename_rel = vim.fn.fnamemodify(orphan.file, ":~:.")

    table.insert(qf_list, {
      filename = orphan.file,
      lnum = 1,
      col = 1,
      text = orphan.reason,
    })
  end

  return qf_list
end

-- Format dead links for display in quickfix list
---@param dead_links table[] List of dead link objects
---@return table[] Quickfix list entries
function M.format_dead_links_for_quickfix(dead_links)
  local qf_list = {}

  for _, link in ipairs(dead_links) do
    local filename_rel = vim.fn.fnamemodify(link.file, ":~:.")
    local text = string.format('Dead link: "%s" -> %s', link.text, link.target)

    table.insert(qf_list, {
      filename = link.file,
      lnum = link.line_num,
      col = 1,
      text = text,
    })
  end

  return qf_list
end

return M
