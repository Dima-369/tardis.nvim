local Job = require('plenary.job')
local util = require('tardis-nvim.util')

local M = {}

---@param root string
---@param ... string
---@return string[]
local function git(root, ...)
    -- Try to resolve git root; bail out if not a git repo
    local rev = Job:new{
        command = 'git',
        args = { '-C', root, 'rev-parse', '--show-toplevel' },
    }:sync()
    root = rev and rev[1]
    if not root or root == '' then
        return {}
    end
    local output = Job:new{
        command = 'git',
        args = { '-C', root, ... },
        on_stderr = function(_, msg)
            vim.schedule(function()
                vim.notify('Tardis: git failed: ' .. msg, vim.log.levels.WARN)
            end)
        end,
    }:sync()
    return output or {}
end

---@param path string
---@return string
local function get_git_file_path(path)
    local root = util.dirname(path)
    local out = git(root, 'ls-files', '--full-name', path)
    return out and out[1]
end

---@param revision string
---@param parent TardisSession
---@return string[]
function M.get_file_at_revision(revision, parent)
    local root = util.dirname(parent.path)
    local file = get_git_file_path(parent.path)
    if not file or file == '' then
        return { 'File is not tracked by git or outside a git repository.' }
    end
    return git(root, 'show', string.format('%s:%s', revision, file))
end

---@param parent TardisSession
---@return string
function M.get_revision_under_cursor(parent)
    local buf = parent:get_current_buffer()
    if not buf then return '' end
    local current_revision = buf.revision
    local root = util.dirname(parent.path)
    local line, _ = vim.api.nvim_win_get_cursor(0)
    local blame = git(root, 'blame', '-L', line, current_revision)
    local blame_line = blame and blame[1] or ''
    return (vim.split(blame_line, ' ', {})[1] or '')
end

---@param parent TardisSession
---@return string[]
function M.get_revisions_for_current_file(parent)
    local root = util.dirname(parent.path)
    local file = get_git_file_path(parent.path)
    if not file or file == '' then
        return {}
    end
    return git(root, 'log', '-n', parent.parent.config.settings.max_revisions, '--pretty=format:%h', '--', file)
end

---@param revision string
---@param parent TardisSession
function M.get_revision_info(revision, parent)
    local root = util.dirname(parent.path)
    local out = git(root, 'show', '--compact-summary', revision)
    return out or {}
end

---@param revision string
---@param parent TardisSession
---@return string
function M.get_revision_relative_time(revision, parent)
    local root = util.dirname(parent.path)
    local result = git(root, 'show', '--pretty=format:%cr', '--no-patch', revision)
    return (result and result[1]) or ''
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
