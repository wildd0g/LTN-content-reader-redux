-- Combinator Updater Module
-- Handles updating constant combinator signals with LTN data

local ltn_interface = require("scripts/ltn-interface")

local combinator_updater = {}

-- Constants
local MAX_SIGNALS = 1000  -- Factorio 2.0 constant combinator limit
local SIGNAL_MAX =  2147483647
local SIGNAL_MIN = -2147483648

-- The bitmask pattern of the boolean settings
local PROVIDER_BIN =      tonumber("0000000000000001",2)
local DELIVER_BIN =       tonumber("0000000000000010",2)
local REQUESTER_BIN =     tonumber("0000000000000100",2)
local ALLNETWORK_BIN =    tonumber("0000000000010000",2)
local EXACTNETWORK_BIN =  tonumber("0000000000100000",2)
local ALLSURFACES_BIN =   tonumber("0000000100000000",2)


-- Parse item string format "type,name" into components
local function parse_item_string(item_string)
  local item_type, item_name, item_quality = string.match(item_string, '^([^,]+),([^,]+),?([^,]*)')
  item_quality = (item_quality and #item_quality > 0) and item_quality or 'normal'
  return item_type, item_name, item_quality
end

-- Validate that an item/fluid prototype exists
local function is_valid_signal(item_type, item_name)
  if item_type == "item" then
    return prototypes.item[item_name] ~= nil
  elseif item_type == "fluid" then
    return prototypes.fluid[item_name] ~= nil
  end
  return false
end

-- Clamp signal value to valid range
local function clamp_signal(value)
  if value > SIGNAL_MAX then return SIGNAL_MAX end
  if value < SIGNAL_MIN then return SIGNAL_MIN end
  return value
end

--helper function to get the boolean settings of a state from the number that represents them
function combinator_updater.bool_settings_num_to_state(boolsettings)
  state = {
    provider = false,
    deliver = false,
    requester = false,
    all_networks = false,
    exact_network = false,
    network_id = 0,
    all_surfaces = false,
    surface_idx = 0
  }
  if bit32.btest(boolsettings, PROVIDER_BIN) then state.provider = true end
  if bit32.btest(boolsettings, DELIVER_BIN) then state.deliver = true end
  if bit32.btest(boolsettings, REQUESTER_BIN) then state.requester = true end
  if bit32.btest(boolsettings, ALLNETWORK_BIN) then state.all_networks = true end
  if bit32.btest(boolsettings, EXACTNETWORK_BIN) then state.exact_network = true end
  if bit32.btest(boolsettings, ALLSURFACES_BIN) then state.all_surfaces = true end
  return state
end

-- Helper function to get the number representing the boolean settings in the state
function combinator_updater.bool_settings_state_to_num(state)
  boolsettings = 0
  if state.provider then boolsettings = bit32.bor(boolsettings, PROVIDER_BIN) end
  if state.deliver then boolsettings = bit32.bor(boolsettings, DELIVER_BIN) end
  if state.requester then boolsettings = bit32.bor(boolsettings, REQUESTER_BIN) end
  if state.all_networks then boolsettings = bit32.bor(boolsettings, ALLNETWORK_BIN) end
  if state.exact_network then boolsettings = bit32.bor(boolsettings, EXACTNETWORK_BIN) end
  if state.all_surfaces then boolsettings = bit32.bor(boolsettings, ALLSURFACES_BIN) end
  return boolsettings
end

-- Helper function to stringify the settings state
function combinator_updater.state_to_string(state)
  nethex = string.sub(string.format("%08X", state.network_id), -8)
  surfhex = string.sub(string.format("%08X", state.surface_idx), -8)
  boolsettingsnum = combinator_updater.bool_settings_state_to_num(state)
  boolsettingshex = string.sub(string.format("%04X", boolsettingsnum), -4)
  return surfhex .. "-" .. nethex .. "-" .. boolsettingshex
end

--helper function to completely clear a section of all signals
local function clear_section(section)
  local cleared_slots = 0
  for i = 1, MAX_SIGNALS do
    if section.get_slot(i) then
      section.clear_slot(i)
      cleared_slots = cleared_slots + 1
    elseif cleared_slots >= N_signals_pre then
      break  -- No more slots to clear
    end
  end
end


local function get_settings_section(entity)
  local behaviour = entity.get_or_create_control_behavior()
  local settings_section = behaviour.get_section(1)
  return settings_section
end

function combinator_updater.set_network_id(entity, id)
  local settings_section = get_settings_section(entity)
  if id then
    settings_section.set_slot(1, {
      min = id,
      value = { type = "virtual", name = "ltn-network-id", comparator = "=", quality = "normal" }
    })
  end
end

function combinator_updater.set_surface_idx(entity, idx)
  local settings_section = get_settings_section(entity)
  if idx then
    settings_section.set_slot(2, {
      min =idx,
      value = { type = "virtual", name = "signal-map-marker", comparator = "=", quality = "normal" }
    })
  end
end

function combinator_updater.set_boolsettings(entity, state)
  local settings_section = get_settings_section(entity)
  settings_section.set_slot(3, {
    min = combinator_updater.bool_settings_state_to_num(state),
    value = { type = "virtual", name = "signal-check", comparator = "=", quality = "normal" }
  })
end

function combinator_updater.set_state(entity, state)
  combinator_updater.set_network_id(entity, state.network_id)
  combinator_updater.set_surface_idx(entity, state.surface_idx)
  combinator_updater.set_boolsettings(entity, state)
end

function combinator_updater.get_state_from_entity(entity)
  if not combinator_updater.valid_settings(entity) then
    combinator_updater.init_combinator(entity)
  end
  
  local settings_section = get_settings_section(entity)
  local boolsettings = settings_section.get_slot(3).min
  local state = combinator_updater.bool_settings_num_to_state(boolsettings)
  state.network_id =   settings_section.get_slot(1).min
  state.surface_idx =  settings_section.get_slot(2).min
  return state
end

-- Update a single combinator with LTN data
function combinator_updater.update_combinator(entity)
  if not entity.valid then
    return false
  end

  -- Get combinator behavior and ensure section exists
  local behaviour = entity.get_or_create_control_behavior()
  while behaviour.sections_count < 2 do
    behaviour.add_section()
  end
  while behaviour.sections_count > 2 do
    behaviour.remove_section(3)
  end

  local settings_section = behaviour.get_section(1)
  settings_section.active = false
  local signals_section = behaviour.get_section(2)


  -- Get reader state for this entity (includes network_id)
  local state = combinator_updater.get_state_from_entity(entity)
  if not state then
    local new_surface_idx = entity.surface.index
    if LtncrSettings.default_surface == "all" then
      new_surface_idx = ltn_interface.get_all_surfaces_index()
    elseif LtncrSettings.default_surface == "current" then
      --new_surface_idx = entity.surface.index
    end
    -- Default state if missing
    state = {
      provider = false,
      deliver = false,
      requester = false,
      all_networks = false,
      exact_network = false,
      network_id = ltn_interface.get_default_network_id(),
      all_surfaces = false,
      surface_idx = new_surface_idx
    }
  end

  -- Get network ID from state
  local network_id = state.all_networks and -1 or state.network_id or ltn_interface.get_default_network_id()

  -- Get surface index from state
  local surface_idx = state.all_surfaces and ltn_interface.get_all_surfaces_index() or state.surface_idx or entity.surface.index

  -- Get aggregated LTN data based on selected modes
  local items = {}  
  if state.provider then
    for item_string, count in pairs(ltn_interface.get_network_data(network_id, surface_idx, "p", state.exact_network)) do
      items[item_string] = (items[item_string] or 0) + count
    end
  end
  if state.deliver then
    for item_string, count in pairs(ltn_interface.get_network_data(network_id, surface_idx, "d", state.exact_network)) do
      items[item_string] = (items[item_string] or 0) + count
    end
  end
  if state.requester then
    for item_string, count in pairs(ltn_interface.get_network_data(network_id, surface_idx, "r", state.exact_network)) do
      items[item_string] = (items[item_string] or 0) + count
    end
  end
  
  --clear first to prevent signals not being set by it still existing at a later index
  clear_section(signals_section)

  -- Start from slot 1 (no longer need to reserve slot for network ID)
  local slot_index = 1
  local N_signals_pre = signals_section.filters_count
  if LtncrSettings.global_groups then
    signals_section.group = "ltncr-" .. combinator_updater.state_to_string(state)
  else
    signals_section.group = ""
  end
  -- Populate combinator slots with item signals
  for item_string, count in pairs(items) do
    local item_type, item_name, item_quality = parse_item_string(item_string)

    if item_type and item_name and is_valid_signal(item_type, item_name) then
      if slot_index <= MAX_SIGNALS then
        signals_section.set_slot(slot_index, {
          value = { type = item_type, name = item_name, quality = item_quality },
          min = clamp_signal(count)
        })
        slot_index = slot_index + 1
      else
        log(string.format("[LTN Content Reader] Warning: Network %d exceeds %d signals. Not all signals set.",
          network_id, MAX_SIGNALS))
        break
      end
    end
  end



  return true
end

function combinator_updater.update_combinator(entity)
  if not entity.valid then
    return false
  end

  -- Get combinator behavior and ensure section exists
  local behaviour = entity.get_or_create_control_behavior()
  while behaviour.sections_count < 2 do
    behaviour.add_section()
  end
  while behaviour.sections_count > 2 do
    behaviour.remove_section(3)
  end

  local settings_section = behaviour.get_section(1)
  settings_section.active = false
  local signals_section = behaviour.get_section(2)


  -- Get reader state for this entity (includes network_id)
  local state = combinator_updater.get_state_from_entity(entity)
  if not state then
    local new_surface_idx = entity.surface.index
    if LtncrSettings.default_surface == "all" then
      new_surface_idx = ltn_interface.get_all_surfaces_index()
    elseif LtncrSettings.default_surface == "current" then
      --new_surface_idx = entity.surface.index
    end
    -- Default state if missing
    state = {
      provider = false,
      deliver = false,
      requester = false,
      all_networks = false,
      exact_network = false,
      network_id = ltn_interface.get_default_network_id(),
      all_surfaces = false,
      surface_idx = new_surface_idx
    }
  end

  -- Get network ID from state
  local network_id = state.all_networks and -1 or state.network_id or ltn_interface.get_default_network_id()

  -- Get surface index from state
  local surface_idx = state.all_surfaces and ltn_interface.get_all_surfaces_index() or state.surface_idx or entity.surface.index

  -- Get aggregated LTN data based on selected modes
  local items = {}  
  if state.provider then
    for item_string, count in pairs(ltn_interface.get_network_data(network_id, surface_idx, "p", state.exact_network)) do
      items[item_string] = (items[item_string] or 0) + count
    end
  end
  if state.deliver then
    for item_string, count in pairs(ltn_interface.get_network_data(network_id, surface_idx, "d", state.exact_network)) do
      items[item_string] = (items[item_string] or 0) + count
    end
  end
  if state.requester then
    for item_string, count in pairs(ltn_interface.get_network_data(network_id, surface_idx, "r", state.exact_network)) do
      items[item_string] = (items[item_string] or 0) + count
    end
  end
  
  --clear first to prevent signals not being set by it still existing at a later index
  clear_section(signals_section)

  -- Start from slot 1 (no longer need to reserve slot for network ID)
  local slot_index = 1
  local N_signals_pre = signals_section.filters_count
  if LtncrSettings.global_groups then
    signals_section.group = "ltncr-" .. combinator_updater.state_to_string(state)
  else
    signals_section.group = ""
  end
  -- Populate combinator slots with item signals
  for item_string, count in pairs(items) do
    local item_type, item_name, item_quality = parse_item_string(item_string)

    if item_type and item_name and is_valid_signal(item_type, item_name) then
      if slot_index <= MAX_SIGNALS then
        signals_section.set_slot(slot_index, {
          value = { type = item_type, name = item_name, quality = item_quality },
          min = clamp_signal(count)
        })
        slot_index = slot_index + 1
      else
        log(string.format("[LTN Content Reader] Warning: Network %d exceeds %d signals. Not all signals set.",
          network_id, MAX_SIGNALS))
        break
      end
    end
  end



  return true
end

-- Update all tracked combinators spread across ticks
function combinator_updater.on_tick(event)
  local update_interval = storage.ltn_update_interval or 60
  local offset = event.tick % update_interval

  local combinators = {}
  if LtncrSettings.global_groups then
    combinators = storage.primary_logistics_group_readers or {}
  else
    combinators = storage.content_readers or {}
  end
  local count = #combinators

  -- Update combinators with matching tick offset
  for i = count - offset, 1, -1 * update_interval do
    if i >= 1 and i <= count then
      local entity = combinators[i]
      if entity and entity.valid then
        combinator_updater.update_combinator(entity)
      else
        -- Remove invalid entity
        table.remove(combinators, i)
      end
    end
  end

  -- Unregister tick handler if no more combinators
  if #combinators == 0 then
    script.on_event(defines.events.on_tick, nil)
  end
end

-- Initialize a newly created reader entity
function combinator_updater.init_combinator(entity)
  -- Just ensure the combinator has a section for signals
  local behaviour = entity.get_or_create_control_behavior()
  while behaviour.sections_count < 2 do
    behaviour.add_section()
  end
  while behaviour.sections_count > 2 do
    behaviour.remove_section(3)
  end

  clear_section(get_settings_section(entity))

  network_id = ltn_interface.get_default_network_id()
  combinator_updater.set_network_id(entity, network_id)
  
  local new_surface_idx = entity.surface.index
  if LtncrSettings.default_surface == "all" then
    new_surface_idx = ltn_interface.get_all_surfaces_index()
  elseif LtncrSettings.default_surface == "current" then
    --new_surface_idx = entity.surface.index
  end
  combinator_updater.set_surface_idx(entity, new_surface_idx)
  
  -- Default boolstate
  new_state = {
    provider = false,
    deliver = false,
    requester = false,
    all_networks = false,
    exact_network = false,
    all_surfaces = false,
  }
  combinator_updater.set_boolsettings(entity, new_state)
  combinator_updater.update_combinator(entity)
end

function combinator_updater.valid_settings(entity)
  local behaviour = entity.get_or_create_control_behavior()

  if  behaviour.sections_count < 1 then
    return false
  end
  
  local settings_section = behaviour.get_section(1)

  if not settings_section.get_slot(1).value or
     not settings_section.get_slot(2).value or
     not settings_section.get_slot(3).value then
    return false
  end

  if not settings_section.get_slot(1).value.name or
     not settings_section.get_slot(2).value.name or
     not settings_section.get_slot(3).value.name then
    return false
  end

  if settings_section.get_slot(1).value.name ~= "ltn-network-id" or
     settings_section.get_slot(2).value.name ~= "signal-map-marker" or
     settings_section.get_slot(3).value.name ~= "signal-check" then
    return false
  end

  return true
end

return combinator_updater
