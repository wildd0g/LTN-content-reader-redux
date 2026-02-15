-- LTN Content Reader New - Main Control Script
-- A well-organized mod for viewing LTN network content with Provider/Requester filtering

-- Load modules
local settings_manager = require("scripts/settings")
local ltn_interface = require("scripts/ltn-interface")
local entity_tracker = require("scripts/entity-tracker")
local gui = require("scripts/gui")
local combinator_updater = require("scripts/combinator-updater")

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

local function init_storage()
  -- LTN data storage
  storage.ltn_stops = storage.ltn_stops or {}
  storage.ltn_provided = storage.ltn_provided or {}
  storage.ltn_requested = storage.ltn_requested or {}
  storage.ltn_deliveries = storage.ltn_deliveries or {}
  storage.ltn_update_interval = storage.ltn_update_interval or 60

  -- Reader entity tracking
  storage.content_readers = storage.content_readers or {}
  storage.reader_states = storage.reader_states or {}

  -- GUI tracking for real-time updates
  storage.open_guis = storage.open_guis or {}
end

-- Master tick handler that coordinates all tick-based updates
local function on_tick(event)
  -- Always update combinators when readers exist
  if storage.content_readers and #storage.content_readers > 0 then
    combinator_updater.on_tick(event)
  end

  -- Always update open GUIs when they exist
  if storage.open_guis then
    local has_open_guis = false
    for _ in pairs(storage.open_guis) do
      has_open_guis = true
      break
    end

    if has_open_guis then
      gui.on_tick(event)
    end
  end
end

-- Register or unregister tick handler based on whether we need it
-- Made global so modules can call it
function register_tick_handler()
  local needs_tick = false

  -- Check if we have readers (for combinator updates)
  if storage.content_readers and #storage.content_readers > 0 then
    needs_tick = true
  end

  -- Check if we have open GUIs (for GUI updates)
  if storage.open_guis then
    for _ in pairs(storage.open_guis) do
      needs_tick = true
      break
    end
  end

  if needs_tick then
    script.on_event(defines.events.on_tick, on_tick)
  else
    script.on_event(defines.events.on_tick, nil)
  end
end

local function register_events()
  -- LTN integration events
  ltn_interface.register_events()

  -- Runtime setting changes

  script.on_event(defines.events.on_runtime_mod_setting_changed, settings_manager.on_setting_changed)
  script.on_event(defines.events.on_runtime_mod_setting_changed, ltn_interface.on_setting_changed)

  -- Entity lifecycle events
  
  -- do per event registration to use event filtering and improve performance
  local entity_filter_mod_entity_names = {{filter = "name", name = "ltn-content-reader"}}
  
  script.on_event(defines.events.on_built_entity, entity_tracker.on_entity_created, entity_filter_mod_entity_names)
  script.on_event(defines.events.on_robot_built_entity, entity_tracker.on_entity_created, entity_filter_mod_entity_names)
  script.on_event(defines.events.on_space_platform_built_entity, entity_tracker.on_entity_created, entity_filter_mod_entity_names)

  script.on_event(defines.events.on_pre_player_mined_item, entity_tracker.on_entity_removed, entity_filter_mod_entity_names)
  script.on_event(defines.events.on_robot_pre_mined, entity_tracker.on_entity_removed, entity_filter_mod_entity_names)
  script.on_event(defines.events.on_space_platform_pre_mined, entity_tracker.on_entity_removed, entity_filter_mod_entity_names)
  script.on_event(defines.events.on_entity_died, entity_tracker.on_entity_removed, entity_filter_mod_entity_names)

  -- GUI events
  script.on_event(defines.events.on_gui_opened, gui.on_gui_opened)
  script.on_event(defines.events.on_gui_closed, gui.on_gui_closed)
  script.on_event(defines.events.on_gui_click, gui.on_gui_click)
  script.on_event(defines.events.on_gui_checked_state_changed, gui.on_gui_checked_state_changed)
  script.on_event(defines.events.on_gui_text_changed, gui.on_gui_text_changed)

  -- Register tick handler if needed
  register_tick_handler()
end

--------------------------------------------------------------------------------
-- Lifecycle Events
--------------------------------------------------------------------------------

script.on_init(function()
  init_storage()
  ltn_interface.init()
  register_events()
end)

script.on_configuration_changed(function()
  init_storage()
  ltn_interface.init()
  register_events()

  -- Validate existing entities
  entity_tracker.validate_entities()
end)

script.on_load(function()
  register_events()
end)

--------------------------------------------------------------------------------
-- Remote Interface
--------------------------------------------------------------------------------

remote.add_interface("ltn_content_reader", {
  -- Get the state of a specific reader entity
  get_reader_state = function(entity)
    if not entity or not entity.valid or entity.name ~= "ltn-content-reader" then
      return nil
    end
    return entity_tracker.get_reader_state(entity)
  end,

  -- Get all reader entities and their states
  get_all_readers = function()
    local readers = {}
    for unit_number, state in pairs(storage.reader_states or {}) do
      readers[unit_number] = state
    end
    return readers
  end,

  -- Update reader state programmatically
  update_reader_state = function(entity, new_state)
    if not entity or not entity.valid or entity.name ~= "ltn-content-reader" then
      return false
    end
    local malormend_state = false
    malormend_state = malormend_state and newstate.requester ~= nil
    malormend_state = malormend_state and newstate.deliver ~= nil
    malormend_state = malormend_state and newstate.requester ~= nil
    malormend_state = malormend_state and newstate.all_networks ~= nil
    malormend_state = malormend_state and newstate.network_id ~= nil
    malormend_state = malormend_state and newstate.exact_network ~= nil
    malormend_state = malormend_state and newstate.all_surfaces ~= nil
    malormend_state = malormend_state and newstate.surface_idx ~= nil
    if malormend_state then
      return false
    end
    return entity_tracker.update_reader_state(entity, new_state)
  end
})
