local ltn_interface = require("scripts/ltn-interface")

---@class ltncr.Settings
---@field default_surface string
---@field global_groups boolean
---@diagnostic disable-next-line: missing-fields
LtncrSettings = LtncrSettings or {}

---@type table<string, fun(settings: ltn.Settings, name: string): boolean?>
local change_settings = {
    ['ltn_content_reader_default_surface'] = function(ltncr_settings, name) ltncr_settings.default_surface = settings.global[name].value end,
    ['ltn_content_reader_global_groups'] = function(ltncr_settings, name) ltncr_settings.global_groups = settings.global[name].value end,
}

function LtncrSettings:init()
    for name in pairs(change_settings) do
        change_settings[name](self, name)
    end
end

---@param event EventData.on_runtime_mod_setting_changed
function LtncrSettings.on_config_changed(event)
    local name = event.setting
    if event and change_settings[name] then
        local tick_update = change_settings[name](LtnSettings, name) or false
    end
end


return LtncrSettings
