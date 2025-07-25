local adapters = require('tardis-nvim.adapters')
local buffer = require('tardis-nvim.buffer')

local M = {}

---@class TardisSession
---@field parent TardisSessionManager
---@field augroup integer
---@field filename string
---@field filetype string
---@field path string
---@field origin integer
---@field buffers TardisBuffer[]
---@field adapter TardisAdapter
M.Session = {}

---@param parent TardisSessionManager
---@param adapter TardisAdapter?
function M.Session:new(parent, adapter)
    local session = {}
    setmetatable(session, self)
    self.__index = self
    session:init(parent, adapter)

    return session
end

---@param revision string
function M.Session:create_buffer(index)
    local fd = vim.api.nvim_create_buf(false, true)
    local revision = self.log[index]
    local file_at_revision = self.adapter.get_file_at_revision(revision, self)

    vim.api.nvim_buf_set_lines(fd, 0, -1, false, file_at_revision)
    vim.api.nvim_set_option_value('filetype', self.filetype, { buf = fd })
    vim.api.nvim_set_option_value('readonly', true, { buf = fd })
    local short_time = self.adapter.get_revision_relative_time_short and self.adapter.get_revision_relative_time_short(revision, self) or ''
    local total_revisions = #self.log
    local filename = vim.fn.fnamemodify(self.filename, ':t') -- Get just the filename without path
    local buffer_name = short_time ~= '' and 
        string.format('%s (%s %d|%d %s)', filename, revision, index, total_revisions, short_time) or
        string.format('%s (%s %d|%d)', filename, revision, index, total_revisions)
    vim.api.nvim_buf_set_name(fd, buffer_name)

    local keymap = self.parent.config.keymap
    vim.keymap.set('n', keymap.next, function()
        self:next_buffer()
    end, { buffer = fd, desc = 'Next entry (older)' })
    vim.keymap.set('n', keymap.prev, function()
        self:prev_buffer()
    end, { buffer = fd, desc = 'Previous entry (newer)' })
    vim.keymap.set('n', keymap.quit, function()
        self:close()
    end, { buffer = fd, desc = 'Quit' })
    vim.keymap.set('n', keymap.revision_message, function()
        self:create_info_buffer(revision)
    end, { buffer = fd, desc = 'Show revision message' })
    vim.keymap.set('n', keymap.commit, function()
        self:commit_to_origin()
    end, { buffer = fd, desc = 'Replace origin buffer with this tardis buffer' })
    vim.keymap.set('n', keymap.revision_picker, function()
        self:show_revision_picker()
    end, { buffer = fd, desc = 'Show revision picker' })

    return buffer.Buffer:new(fd)
end

function M.Session:create_info_buffer(revision)
    local message = self.adapter.get_revision_info(revision, self)
    if not message or #message == 0 then
        vim.notify('revision_message was empty')
        return
    end
    
    -- Create buffer for the revision info
    local fd = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(fd, 0, -1, false, message)
    vim.api.nvim_set_option_value('filetype', 'gitcommit', { buf = fd })
    vim.api.nvim_set_option_value('readonly', true, { buf = fd })
    vim.api.nvim_set_option_value('modifiable', false, { buf = fd })
    
    -- Calculate window dimensions
    local editor_width = vim.o.columns
    local editor_height = vim.o.lines
    
    -- Calculate content dimensions
    local content_width = 0
    for _, line in ipairs(message) do
        content_width = math.max(content_width, vim.fn.strdisplaywidth(line))
    end
    
    -- Set window dimensions with reasonable limits
    local win_width = math.min(content_width + 4, math.floor(editor_width * 0.8))
    local win_height = math.min(#message + 2, math.floor(editor_height * 0.6))
    
    -- Center the window
    local row = math.floor((editor_height - win_height) / 2)
    local col = math.floor((editor_width - win_width) / 2)
    
    -- Create floating window
    local win_id = vim.api.nvim_open_win(fd, true, {
        relative = 'editor',
        width = win_width,
        height = win_height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
        title = string.format(' Revision %s ', revision),
        title_pos = 'center',
    })
    
    -- Set window options
    vim.api.nvim_set_option_value('wrap', true, { win = win_id })
    vim.api.nvim_set_option_value('linebreak', true, { win = win_id })
    vim.api.nvim_set_option_value('breakindent', true, { win = win_id })
    
    -- Add keymaps to close the window
    local close_win = function()
        if vim.api.nvim_win_is_valid(win_id) then
            vim.api.nvim_win_close(win_id, true)
        end
    end
    
    vim.keymap.set('n', 'q', close_win, { buffer = fd, desc = 'Close revision info' })
    vim.keymap.set('n', '<Esc>', close_win, { buffer = fd, desc = 'Close revision info' })
    vim.keymap.set('n', '<CR>', close_win, { buffer = fd, desc = 'Close revision info' })
    
    -- Auto-close when leaving the window
    vim.api.nvim_create_autocmd({ 'BufLeave', 'WinLeave' }, {
        buffer = fd,
        once = true,
        callback = close_win,
    })
end

function M.Session:show_revision_picker()
    -- Check if fzf-lua is available
    local ok, fzf = pcall(require, 'fzf-lua')
    if not ok then
        vim.notify('fzf-lua is required for revision picker', vim.log.levels.ERROR)
        return
    end
    
    -- Check if adapter supports detailed revisions
    if not self.adapter.get_revisions_with_details then
        vim.notify('Revision picker not supported by current adapter', vim.log.levels.WARN)
        return
    end
    
    -- Get revisions with details
    local revisions = self.adapter.get_revisions_with_details(self)
    if vim.tbl_isempty(revisions) then
        vim.notify('No revisions found', vim.log.levels.WARN)
        return
    end
    
    -- Format entries for fzf
    local entries = {}
    
    for i, rev in ipairs(revisions) do
        local entry = string.format("%-8s %-15s %s", rev.hash, rev.relative_time, rev.summary)
        table.insert(entries, entry)
    end
    
    -- Show fzf picker
    fzf.fzf_exec(entries, {
        prompt = 'Revisions> ',
        fzf_opts = {
            ['--layout'] = 'reverse-list',
            ['--info'] = 'inline',
            ['--with-nth'] = '1..',
        },
        preview = function(selected)
            if not selected or #selected == 0 then
                return ''
            end
            
            -- Extract hash from the selected line
            local hash = vim.split(selected[1], ' ', { plain = true })[1]
            if not hash then
                return ''
            end
            
            -- Get revision info for preview
            local info = self.adapter.get_revision_info and self.adapter.get_revision_info(hash, self) or {}
            return table.concat(info, '\n')
        end,
        actions = {
            ['default'] = function(selected)
                if not selected or #selected == 0 then
                    return
                end
                
                -- Extract hash from the selected line
                local hash = vim.split(selected[1], ' ', { plain = true })[1]
                if not hash then
                    return
                end
                
                -- Find the index of this revision in our log
                local target_index = nil
                for i, log_hash in ipairs(self.log) do
                    if log_hash == hash then
                        target_index = i
                        break
                    end
                end
                
                if target_index then
                    self:goto_buffer(target_index)
                else
                    vim.notify('Selected revision not found in current session', vim.log.levels.WARN)
                end
            end
        },
        winopts = {
            height = 0.6,
            width = 0.8,
            preview = {
                layout = 'vertical',
                vertical = 'up:50%'
            }
        }
    })
end

---@param parent TardisSessionManager
---@param adapter_type string
function M.Session:init(parent, adapter_type)
    local adapter = adapters.get_adapter(adapter_type)
    if not adapter then
        return
    end

    self.adapter = adapter
    self.filetype = vim.api.nvim_get_option_value('filetype', { buf = 0 })
    self.filename = vim.api.nvim_buf_get_name(0)
    self.origin = vim.api.nvim_get_current_buf()
    self.parent = parent
    self.path = vim.fn.expand('%:p')
    self.buffers = {}
    self.log = self.adapter.get_revisions_for_current_file(self)

    if vim.tbl_isempty(self.log) then
        vim.notify('No previous revisions of this file were found', vim.log.levels.WARN)
        return
    end

    parent:on_session_opened(self)
end

function M.Session:close()
    for _, buf in ipairs(self.buffers) do
        buf:close()
    end
    if self.parent then
        self.parent:on_session_closed(self)
    end
end

---@return TardisBuffer
function M.Session:get_current_buffer()
    return self.buffers[self.curret_buffer_index]
end

---@param index integer
function M.Session:goto_buffer(index)
    if index < 1 or index >= #self.log then
        return false
    end
    if not self.buffers[index] then
        self.buffers[index] = self:create_buffer(index)
    end
    self.buffers[index]:focus()
    self.curret_buffer_index = index
    return true
end

function M.Session:next_buffer()
    if not self:goto_buffer(self.curret_buffer_index + 1) then
        vim.notify('No earlier revisions of file')
    end
end

function M.Session:prev_buffer()
    if not self:goto_buffer(self.curret_buffer_index - 1) then
        vim.notify('No later revisions of file')
    end
end

function M.Session:commit_to_origin()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    vim.api.nvim_buf_set_lines(self.origin, 0, -1, false, lines)
    self:close()
end

return M
