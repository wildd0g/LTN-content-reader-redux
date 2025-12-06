-- Combinator Updater Module
-- Handles updating constant combinator signals with LTN data

local ltn_interface = require("scripts/ltn-interface")

local combinator_updater = {}

-- Constants
local MAX_SIGNALS = 1000  -- Factorio 2.0 constant combinator limit
local SIGNAL_MAX =  2147483647
local SIGNAL_MIN = -2147483648

-- Parse item string format "type,name" into components
local function parse_item(item_string)
  local item_type, item_name = string.match(item_string, "([^,]+),([^,]+)")
  return item_type, item_name
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

-- Update a single combinator with LTN data
function combinator_updater.update_combinator(entity)
  if not entity.valid then
    return false
  end

  -- Get combinator behavior and ensure section exists
  local behaviour = entity.get_or_create_control_behavior()
  if behaviour.sections_count == 0 then
    behaviour.add_section()
  end
  local section = behaviour.get_section(1)

  -- Get reader state for this entity (includes network_id)
  local unit_number = entity.unit_number
  local state = storage.reader_states and storage.reader_states[unit_number]
  if not state then
    -- Default state if missing
    state = {
      provider = false,
      deliver = false,
      requester = false,
      all_networks = false,
      exact_network = false,
      network_id = ltn_interface.get_default_network_id(),
      all_surfaces = false,
      surface_idx = entity.surface.index
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
  
  
  -- Start from slot 1 (no longer need to reserve slot for network ID)
  local slot_index = 1
  
  -- Populate combinator slots with item signals
  for item_string, count in pairs(items) do
    local item_type, item_name = parse_item(item_string)

    if item_type and item_name and is_valid_signal(item_type, item_name) then
      if slot_index <= MAX_SIGNALS then
        section.set_slot(slot_index, {
          value = { type = item_type, name = item_name, quality = "normal" },
          min = clamp_signal(count)
        })
        slot_index = slot_index + 1
      else
        log(string.format("[LTN Content Reader] Warning: Network %d exceeds %d signals. Not all signals displayed.",
          network_id, MAX_SIGNALS))
        break
      end
    end
  end

  -- Clear any remaining slots from previous updates
  for i = slot_index, MAX_SIGNALS do
    if section.get_slot(i) then
      section.clear_slot(i)
    else
      break  -- No more slots to clear
    end
  end

  return true
end

-- Update all tracked combinators spread across ticks
function combinator_updater.on_tick(event)
  local update_interval = storage.ltn_update_interval or 60
  local offset = event.tick % update_interval

  local combinators = storage.content_readers or {}
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
  if behaviour.sections_count == 0 then
    behaviour.add_section()
  end

  -- Do initial update (network ID is now stored in state, not in combinator)
  combinator_updater.update_combinator(entity)
end

return combinator_updater
