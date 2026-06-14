
---@class ltncr.Settings
---@field default_surface string
---@field global_groups boolean
---@diagnostic disable-next-line: missing-fields
local combinator_updater = require("scripts/combinator-updater")
local entity_tracker = require("scripts/entity-tracker")
LtncrSettings = LtncrSettings or {}

---@type table<string, fun(settings: ltncr.Settings, name: string): boolean?>
local change_settings = {
    ['ltn_content_reader_default_surface'] = function(ltncr_settings, name) ltncr_settings.default_surface = settings.global[name].value end,
    ['ltn_content_reader_global_groups'] = function(ltncr_settings, name) 
        ltncr_settings.global_groups = settings.global[name].value
        -- Take action on change during running game
        if game ~= nil then
            -- (de)register logistics groups for all content readers
            if ltncr_settings.global_groups then
                -- Manual update for specific content reader updates the logistics group
                for _, content_reader in pairs(storage.content_readers) do
                    combinator_updater.update_combinator(content_reader)
                end
            else
                entity_tracker.clear_all_logistics_groups()
            end
        end
    end,
}

function LtncrSettings:init()
    for name in pairs(change_settings) do
        change_settings[name](self, name)
    end
    return self
end

---@param event EventData.on_runtime_mod_setting_changed
function LtncrSettings.on_setting_changed(event)
    local name = event.setting
    if event and change_settings[name] then
        change_settings[name](LtncrSettings, name)
    end
end


return LtncrSettings
