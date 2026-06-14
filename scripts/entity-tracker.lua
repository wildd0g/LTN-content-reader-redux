-- Entity Tracker Module
-- Manages lifecycle of LTN Content Reader entities

local combinator_updater = require("scripts/combinator-updater")
local ltn_interface = require("scripts/ltn-interface")

local entity_tracker = {}


local function group_name_is_ltncr_group(group_name)
  local patern = "^ltncr%-%x%x%x%x%x%x%x%x%-%x%x%x%x%x%x%x%x%-%x%x%x%x$"
  return group_name:find(patern) ~= nil
end

local function update_all_ltncr_logistics_groups()
  local force_group_name_pairs = {}
  local group_reader_entities = {}
  for i, force in pairs(game.forces) do
    local force_logistic_group_names = force.get_logistic_groups()
    for j=1, #force_logistic_group_names do
      local group_name = force_logistic_group_names[j]
      
      if group_name_is_ltncr_group(group_name) then
        table.insert(force_group_name_pairs, {force, group_name})
        
        local group = force.get_logistic_group(group_name)
        if #group.members > 0 then
          for k=1, #group.members do
            local potential_content_reader_entity = group.members[k].owner
            if potential_content_reader_entity.name == "ltn-content-reader" then
              table.insert(group_reader_entities, potential_content_reader_entity)
              break
            end
          end
        end  

      end

    end
  end
  storage.force_logistics_group_names_pairs = force_group_name_pairs
  storage.primary_logistics_group_readers = group_reader_entities

end

function entity_tracker.get_all_ltncr_logistics_force_group_names_pairs()
  return storage.force_logistics_group_names_pairs or {}
end

function entity_tracker.clear_unused_logistics_groups()
  update_all_ltncr_logistics_groups()
  force_group_name_pairs = entity_tracker.get_all_ltncr_logistics_force_group_names_pairs()
  for i=1, #force_group_name_pairs do
    local force = force_group_name_pairs[i][1]
    local group_name = force_group_name_pairs[i][2]
    local group = force.get_logistic_group(group_name)
    if #group.members == 0 then
      force.delete_logistic_group(group_name)
    else
      has_valid_reader = false
      for j=1, #group.members do
        local potential_content_reader_entity = group.members[j].owner
        if potential_content_reader_entity.name == "ltn-content-reader" then
          has_valid_reader = true
          break
        end
      end
      if not has_valid_reader then
        force.delete_logistic_group(group_name)
      end
    end
  end
end

function entity_tracker.clear_all_logistics_groups()
  update_all_ltncr_logistics_groups()
  force_group_name_pairs = entity_tracker.get_all_ltncr_logistics_force_group_names_pairs()
  for i=1, #force_group_name_pairs do
    force_group_name_pairs[i][1].delete_logistic_group(force_group_name_pairs[i][2])
  end
end

-- Add a reader entity to tracking
function entity_tracker.add_reader(entity)
  if not entity or not entity.valid then
    return false
  end

  if entity.name ~= "ltn-content-reader" then
    return false
  end

  -- Initialize combinator with network ID, if it doen't have one yet (from a BP)
  -- Or set the logistics group to be the global logistics group for its setting
  if not combinator_updater.valid_settings(entity) or LtncrSettings.global_groups then
    combinator_updater.init_combinator(entity)
  end

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

  if LtncrSettings.global_groups then
    update_all_ltncr_logistics_groups()
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

  if LtncrSettings.global_groups then
    entity_tracker.clear_unused_logistics_groups()
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
  return combinator_updater.get_state_from_entity(entity)
end


-- Update reader state and trigger combinator update
function entity_tracker.update_reader_state(entity, new_state)
  combinator_updater.set_state(entity, new_state)

  -- Immediately update the combinator with new state
  combinator_updater.update_combinator(entity)

    -- Remove empty groups if this change left one empty
  if LtncrSettings.global_groups then
    entity_tracker.clear_unused_logistics_groups()
  end

  return true
end

-- Update only surface index and trigger combinator update
function entity_tracker.set_network_id(entity, network_id, all_networks_checkbox)
  local state = entity_tracker.get_reader_state(entity)
  if state then
    if all_networks_checkbox ~= nil then
      state.all_networks = all_networks_checkbox
      combinator_updater.set_boolsettings(entity, state)
    end
    if network_id ~= nil then
      combinator_updater.set_network_id(entity, network_id)
    end

    -- Immediately update the combinator with new network ID
    combinator_updater.update_combinator(entity)

    if LtncrSettings.global_groups then
      entity_tracker.clear_unused_logistics_groups()
    end

    return true
  end

  if LtncrSettings.global_groups then
    entity_tracker.clear_unused_logistics_groups()
  end

  return false
end

-- Update only surface index and trigger combinator update
function entity_tracker.set_surface_idx(entity, surface_idx, all_surfaces_checkbox)
  local state = entity_tracker.get_reader_state(entity)
  if state then
    if all_surfaces_checkbox ~= nil then
      state.all_surfaces = all_surfaces_checkbox
      combinator_updater.set_boolsettings(entity, state)
    end
    if surface_idx ~= nil then
      combinator_updater.set_surface_idx(entity, surface_idx)
    end

    -- Immediately update the combinator with new network ID
    combinator_updater.update_combinator(entity)

    if LtncrSettings.global_groups then
      entity_tracker.clear_unused_logistics_groups()
    end

    return true
  end

  if LtncrSettings.global_groups then
    entity_tracker.clear_unused_logistics_groups()
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
