local M = {}

---@alias TardisKeymap {[string]: string}

---@class TardisSettings
---@field max_revisions integer
---@field initial_revisions integer

---@class TardisConfig
---@field keymap TardisKeymap
---@field settings TardisSettings
---@field callbacks { on_open: (fun(session: TardisSession))? }
--
---@class TardisPartialConfig
---@field keymap? TardisKeymap
---@field settings? TardisSettings
---@field callbacks? { on_open: (fun(session: TardisSession))? }

---@return TardisConfig
local function get_default_config()
    return {
        keymap = {
            ['next'] = '<C-j>',
            ['prev'] = '<C-k>',
            ['quit'] = 'q',
            ['revision_message'] = '<C-m>',
            ['commit'] = '<C-g>',
            ['revision_picker'] = '<C-c>',
        },
        settings = {
            max_revisions = 256,
            initial_revisions = 10,
        },
        callbacks = {
            on_open = nil,
        },
        debug = false,
    }
end

M.Config = {}

---@param user_config TardisPartialConfig?
---@return TardisConfig
function M.Config:new(user_config)
    user_config = user_config or {}
    local default_config = get_default_config()
    local config = vim.tbl_deep_extend('force', default_config, user_config)
    setmetatable(user_config, self)
    self.__index = self
    return config
end

return M
