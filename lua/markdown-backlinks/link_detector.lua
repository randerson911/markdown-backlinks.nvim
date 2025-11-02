-- Link detection for markdown files
-- Finds markdown-style [text](path) and wiki-style [[path]] links

local utils = require("markdown-backlinks.utils")

local M = {}

-- Link patterns
local PATTERNS = {
  -- Markdown links: [text](path)
  markdown = "%[([^%]]+)%]%(([^%)]+)%)",

  -- Wiki links: [[path]] or [[path|text]]
  wiki = "%[%[([^%]|]+)%|?([^%]]*)%]%]",
}

-- Find all links in a buffer
---@param bufnr number Buffer number
---@return table[] Array of link objects
function M.find_links_in_buffer(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local links = {}

  for line_num, line in ipairs(lines) do
    -- Skip if line is in a code block
    if not utils.is_in_code_block(lines, line_num) then
      -- Find markdown links
      local markdown_links = M._find_markdown_links(line, line_num)
      vim.list_extend(links, markdown_links)

      -- Find wiki links
      local wiki_links = M._find_wiki_links(line, line_num)
      vim.list_extend(links, wiki_links)
    end
  end

  return links
end

-- Find markdown-style links in a line
---@param line string Line of text
---@param line_num number Line number (1-indexed)
---@return table[] Array of link objects
function M._find_markdown_links(line, line_num)
  local links = {}
  local pos = 1

  while true do
    -- Find next markdown link
    local text_start, text_end, text, target = line:find(PATTERNS.markdown, pos)

    if not text_start then
      break
    end

    -- Check if link is inside inline code
    if not utils.is_in_inline_code(line, text_start - 1) then
      table.insert(links, {
        pattern = "markdown",
        text = text,
        target = target,
        line_num = line_num,
        col_start = text_start - 1, -- 0-indexed
        col_end = text_end,
      })
    end

    pos = text_end + 1
  end

  return links
end

-- Find wiki-style links in a line
---@param line string Line of text
---@param line_num number Line number (1-indexed)
---@return table[] Array of link objects
function M._find_wiki_links(line, line_num)
  local links = {}
  local pos = 1

  while true do
    -- Find next wiki link
    local text_start, text_end, target, text = line:find(PATTERNS.wiki, pos)

    if not text_start then
      break
    end

    -- Check if link is inside inline code
    if not utils.is_in_inline_code(line, text_start - 1) then
      -- If no text provided, use target as text
      if text == "" then
        text = target
      end

      table.insert(links, {
        pattern = "wiki",
        text = text,
        target = target,
        line_num = line_num,
        col_start = text_start - 1, -- 0-indexed
        col_end = text_end,
      })
    end

    pos = text_end + 1
  end

  return links
end

-- Extract links from text (used for detecting changes)
---@param text string Text to search
---@return string[] Array of link targets
function M.extract_link_targets(text)
  local targets = {}

  -- Find markdown links
  for target in text:gmatch(PATTERNS.markdown) do
    table.insert(targets, target)
  end

  -- Find wiki links
  for target in text:gmatch(PATTERNS.wiki) do
    table.insert(targets, target)
  end

  return targets
end

return M
