-- Entity Tracker Module
-- Manages lifecycle of LTN Content Reader entities

local combinator_updater = require("scripts/combinator-updater")
local ltn_interface = require("scripts/ltn-interface")

local entity_tracker = {}

-- Add a reader entity to tracking
function entity_tracker.add_reader(entity)
  if not entity or not entity.valid then
    return false
  end

  if entity.name ~= "ltn-content-reader" then
    return false
  end

  -- Initialize combinator with network ID
  combinator_updater.init_combinator(entity)

  -- Add to tracked entities
  storage.content_readers = storage.content_readers or {}
  table.insert(storage.content_readers, entity)

  -- Initialize reader state if not exists
  local unit_number = entity.unit_number
  if not storage.reader_states[unit_number] then
    storage.reader_states[unit_number] = {
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

  -- Update tick handler registration
  if register_tick_handler then
    register_tick_handler()
  end

  return true
end

-- Remove a reader entity from tracking
function entity_tracker.remove_reader(entity)
  if not entity then
    return false
  end

  if entity.name ~= "ltn-content-reader" then
    return false
  end

  local unit_number = entity.unit_number

  -- Remove from tracked entities
  if storage.content_readers then
    for i = #storage.content_readers, 1, -1 do
      if storage.content_readers[i].unit_number == unit_number then
        table.remove(storage.content_readers, i)
        break
      end
    end
  end

  -- Remove reader state
  if storage.reader_states then
    storage.reader_states[unit_number] = nil
  end

  -- Update tick handler registration
  if register_tick_handler then
    register_tick_handler()
  end

  return true
end

-- Handle entity creation events
function entity_tracker.on_entity_created(event)
  local entity = event.entity or event.created_entity
  if entity and entity.valid then
    entity_tracker.add_reader(entity)
  end
end

-- Handle entity removal events
function entity_tracker.on_entity_removed(event)
  local entity = event.entity
  if entity then
    entity_tracker.remove_reader(entity)
  end
end

-- Get or create reader state for an entity
function entity_tracker.get_reader_state(entity)
  if not entity or not entity.valid then
    return nil
  end

  local unit_number = entity.unit_number
  if not storage.reader_states[unit_number] then
    storage.reader_states[unit_number] = {
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

  return storage.reader_states[unit_number]
end


-- Update reader state and trigger combinator update
function entity_tracker.update_reader_state(entity, new_state)
  local state = entity_tracker.get_reader_state(entity)
  if state then
    state = new_state

    -- Immediately update the combinator with new state
    combinator_updater.update_combinator(entity)
    return true
  end
  return false
end

-- Update only surface index and trigger combinator update
function entity_tracker.set_network_id(entity, network_id, all_networks_checkbox)
  local state = entity_tracker.get_reader_state(entity)
  if state then
    if all_networks_checkbox ~= nil then
      state.all_networks = all_networks_checkbox
    end
    if network_id ~= nil then
      state.network_id = network_id
    end

    -- Immediately update the combinator with new network ID
    combinator_updater.update_combinator(entity)
    return true
  end
  return false
end

-- Update only surface index and trigger combinator update
function entity_tracker.set_surface_idx(entity, surface_idx, all_surfaces_checkbox)
  local state = entity_tracker.get_reader_state(entity)
  if state then
    if all_surfaces_checkbox ~= nil then
      state.all_surfaces = all_surfaces_checkbox
    end
    if surface_idx ~= nil then
      state.surface_idx = surface_idx
    end

    -- Immediately update the combinator with new network ID
    combinator_updater.update_combinator(entity)
    return true
  end
  return false
end

-- Validate and clean up invalid entities
function entity_tracker.validate_entities()
  if not storage.content_readers then
    return
  end

  for i = #storage.content_readers, 1, -1 do
    if not storage.content_readers[i].valid then
      local unit_number = storage.content_readers[i].unit_number
      table.remove(storage.content_readers, i)

      -- Clean up state
      if storage.reader_states then
        storage.reader_states[unit_number] = nil
      end
    end
  end

  -- Update tick handler registration
  if register_tick_handler then
    register_tick_handler()
  end
end

return entity_tracker
