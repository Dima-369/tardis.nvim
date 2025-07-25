local Job = require('plenary.job')
local util = require('tardis-nvim.util')

local M = {}

---@param root string
---@param ... string
---@return string[]
local function git(root, ...)
    root = Job:new{
        command = 'git',
        args = { '-C', root, 'rev-parse', '--show-toplevel' },
    }:sync()[1]
    local output = Job:new{
        command = 'git',
        args = { '-C', root, ... },
        on_stderr = function(_, msg)
            vim.print('Tardis: git failed: ' .. msg, vim.log.levels.WARN)
        end,
    }:sync()
    return output
end

---@param path string
---@return string
local function get_git_file_path(path)
    local root = util.dirname(path)
    return git(root, 'ls-files', '--full-name', path)[1]
end

---@param revision string
---@param parent TardisSession
---@return string[]
function M.get_file_at_revision(revision, parent)
    local root = util.dirname(parent.path)
    local file = get_git_file_path(parent.path)
    return git(root, 'show', string.format('%s:%s', revision, file))
end

---@param parent TardisSession
---@return string
function M.get_revision_under_cursor(parent)
    local current_revision = parent:get_current_buffer().revision
    local root = util.dirname(parent.path)
    local line, _ = vim.api.nvim_win_get_cursor(0)
    local blame_line = git(root, 'blame', '-L', line, current_revision)[1]
    return vim.split(blame_line, ' ', {})[1]
end

---@param parent TardisSession
---@return string[]
function M.get_revisions_for_current_file(parent)
    local root = util.dirname(parent.path)
    local file = get_git_file_path(parent.path)
    return git(root, 'log', '-n', parent.parent.config.settings.max_revisions, '--pretty=format:%h', '--', file)
end

---@param revision string
---@param parent TardisSession
function M.get_revision_info(revision, parent)
    local root = util.dirname(parent.path)
    return git(root, 'show', '--compact-summary', revision)
end

---@param revision string
---@param parent TardisSession
---@return string
function M.get_revision_relative_time(revision, parent)
    local root = util.dirname(parent.path)
    local result = git(root, 'show', '--pretty=format:%cr', '--no-patch', revision)
    return result[1] or ''
end

---@param time_str string
---@return string
local function shorten_relative_time(time_str)
    if not time_str or time_str == '' then
        return ''
    end
    
    -- Convert common time formats to shorter versions
    local shortened = time_str
        :gsub('(%d+) years? ago', '%1y')
        :gsub('(%d+) months? ago', '%1mo')
        :gsub('(%d+) weeks? ago', '%1w')
        :gsub('(%d+) days? ago', '%1d')
        :gsub('(%d+) hours? ago', '%1h')
        :gsub('(%d+) minutes? ago', '%1m')
        :gsub('(%d+) seconds? ago', '%1s')
        :gsub(' ago', '')
    
    return shortened
end

---@param revision string
---@param parent TardisSession
---@return string
function M.get_revision_relative_time_short(revision, parent)
    local full_time = M.get_revision_relative_time(revision, parent)
    return shorten_relative_time(full_time)
end

---@param parent TardisSession
---@return table[]
function M.get_revisions_with_details(parent)
    local root = util.dirname(parent.path)
    local file = get_git_file_path(parent.path)
    local result = git(root, 'log', '-n', parent.parent.config.settings.max_revisions, 
                      '--pretty=format:%h|%cr|%s', '--', file)
    
    local revisions = {}
    for _, line in ipairs(result) do
        local parts = vim.split(line, '|', { plain = true })
        if #parts >= 3 then
            table.insert(revisions, {
                hash = parts[1],
                relative_time = parts[2],
                summary = parts[3]
            })
        end
    end
    return revisions
end

return M
