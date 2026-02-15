-- LTN Interface Module
-- Handles communication with Logistic Train Network mod via remote interface

local ltn_interface = {}
local all_surfaces_index = -1
-- Default network ID from LTN settings
local default_network = -1

-- Initialize LTN integration
function ltn_interface.init()
  -- Get default network from LTN settings
  if settings and settings.global["ltn-stop-default-network"] then
    default_network = settings.global["ltn-stop-default-network"].value
  end
end

-- Get default network ID
function ltn_interface.get_default_network_id()
  return default_network
end

function ltn_interface.get_all_surfaces_index()
  return all_surfaces_index
end

-- Handle LTN settings changes
function ltn_interface.on_setting_changed(event)
  if event.setting == "ltn-stop-default-network" then
    default_network = settings.global["ltn-stop-default-network"].value
  end
end

-- Handle LTN stops update event
function ltn_interface.on_stops_updated(event)
  storage.ltn_stops = event.logistic_train_stops or {}
end

-- Handle LTN dispatcher update event
function ltn_interface.on_dispatcher_updated(event)
  
  -- Initialize storage tables
  storage.ltn_provided = {}
  storage.ltn_requested = {}
  storage.ltn_deliveries = {}

  storage.ltn_provided[all_surfaces_index] = {}
  storage.ltn_requested[all_surfaces_index] = {}
  storage.ltn_deliveries[all_surfaces_index] = {}
  -- Aggregate provided items by network and surface
  for stop_id, items in pairs(event.provided_by_stop or {}) do
    local network_id = storage.ltn_stops[stop_id] and storage.ltn_stops[stop_id].network_id
    local surface_idx = storage.ltn_stops[stop_id] and storage.ltn_stops[stop_id].entity.surface.index
	  
    if not (surface_idx and network_id) then
      game.print("Malformed ltn stop data on provider:")
      game.print("Stop " .. stop_id .. ": " .. serpent.dump(storage.ltn_stops[stop_id]))
      game.print("Missed items: " .. serpent.dump(items))
    else
		  storage.ltn_provided[surface_idx] = storage.ltn_provided[surface_idx] or {}
      storage.ltn_provided[surface_idx][network_id] = storage.ltn_provided[surface_idx][network_id] or {}
      storage.ltn_provided[all_surfaces_index][network_id] = storage.ltn_provided[all_surfaces_index][network_id] or {}
      for item, count in pairs(items) do
        storage.ltn_provided[surface_idx][network_id][item] = (storage.ltn_provided[surface_idx][network_id][item] or 0) + count
        storage.ltn_provided[all_surfaces_index][network_id][item] = (storage.ltn_provided[all_surfaces_index][network_id][item] or 0) + count
      end
    end
  end

  -- Aggregate requested items by network
  -- event.requests_by_stop = { [stopID] = { [item] = count } }
  for stop_id, items in pairs(event.requests_by_stop or {}) do
    local network_id = storage.ltn_stops[stop_id] and storage.ltn_stops[stop_id].network_id
    local surface_idx = storage.ltn_stops[stop_id] and storage.ltn_stops[stop_id].entity.surface.index

    if not (surface_idx and network_id) then
      game.print("Malformed ltn stop data  on requester:")
      game.print("Stop " .. stop_id .. ": "..serpent.dump(storage.ltn_stops[stop_id]))
      game.print("Missed items: " .. serpent.dump(items))
    else
      storage.ltn_requested[surface_idx] = storage.ltn_requested[surface_idx] or {}
      storage.ltn_requested[surface_idx][network_id] = storage.ltn_requested[surface_idx][network_id] or {}
      storage.ltn_requested[all_surfaces_index][network_id] = storage.ltn_requested[all_surfaces_index][network_id] or {}  
      for item, count in pairs(items) do
        -- Store as negative for requests
        storage.ltn_requested[surface_idx][network_id][item] = (storage.ltn_requested[surface_idx][network_id][item] or 0) - count
        storage.ltn_requested[all_surfaces_index][network_id][item] = (storage.ltn_requested[all_surfaces_index][network_id][item] or 0) - count
      end
    end
  end

  -- Aggregate deliveries by network
  -- event.deliveries = { trainID = {force, train, from, to, network_id, started, shipment = { item = count } } }
  for train_id, delivery in pairs(event.deliveries or {}) do
    local surface_idx = storage.ltn_stops[delivery.from_id] and storage.ltn_stops[delivery.from_id].entity.surface.index

    if not (surface_idx and delivery.network_id) then
      game.print("Malformed ltn stop data on delivery:")
      game.print("Train " .. train_id .. ": " .. serpent.dump(delivery))
      game.print("Missed items: " .. serpent.dump(delivery.shipment))
    else
      storage.ltn_deliveries[surface_idx] = storage.ltn_deliveries[surface_idx] or {}
      storage.ltn_deliveries[surface_idx][delivery.network_id] = storage.ltn_deliveries[surface_idx][delivery.network_id] or {}
      storage.ltn_deliveries[all_surfaces_index][delivery.network_id] = storage.ltn_deliveries[all_surfaces_index][delivery.network_id] or {}
      for item, count in pairs(delivery.shipment) do
        storage.ltn_deliveries[surface_idx][delivery.network_id][item] = (storage.ltn_deliveries[surface_idx][delivery.network_id][item] or 0) + count
        storage.ltn_deliveries[all_surfaces_index][delivery.network_id][item] = (storage.ltn_deliveries[all_surfaces_index][delivery.network_id][item] or 0) + count
      end
    end
  end

  -- Store LTN update interval for tick synchronization
  storage.ltn_update_interval = event.update_interval or 60
end

-- Register LTN event handlers
function ltn_interface.register_events()
  if remote.interfaces["logistic-train-network"] then
    local on_stops_updated = remote.call("logistic-train-network", "on_stops_updated")
    local on_dispatcher_updated = remote.call("logistic-train-network", "on_dispatcher_updated")

    script.on_event(on_stops_updated, ltn_interface.on_stops_updated)
    script.on_event(on_dispatcher_updated, ltn_interface.on_dispatcher_updated)

    return true
  else
    log("[LTN Content Reader] Warning: Logistic Train Network not found")
    return false
  end
end

-- Get aggregated data for a specific network
function ltn_interface.get_network_data(selected_network_id, selected_surface_idx, ltn_table, exact_network)
  
  local items = {}
  selected_network_id = selected_network_id or -1
  selected_surface_idx = selected_surface_idx or 1
  if ltn_table == "ltn_provided" or ltn_table == "p" then
    ltn_table = "ltn_provided"
  elseif ltn_table == "ltn_deliveries" or ltn_table == "d" then
    ltn_table = "ltn_deliveries"
  elseif ltn_table == "ltn_requested" or ltn_table == "r" then
    ltn_table = "ltn_requested"
  else

  end
  reader = {table_name = ltn_table}
  if exact_network == nil then exact_network = false end

  -- Special case: -1 means "all networks"
  local match_all = (selected_network_id == -1)
  if reader then
    storage[reader.table_name][selected_surface_idx] = storage[reader.table_name][selected_surface_idx] or {}
    
    if exact_network then
      for item, count in pairs(storage[reader.table_name][selected_surface_idx][selected_network_id] or {}) do
        items[item] = (items[item] or 0) + count
      end
    
    else
      --normal bitmask match match
      for network_id, item_data in pairs(storage[reader.table_name][selected_surface_idx]) do
        if match_all or bit32.btest(selected_network_id, network_id) then
          for item, count in pairs(item_data) do
            items[item] = (items[item] or 0) + count
          end
        end
      end
    end
  end

  return items
end

return ltn_interface
