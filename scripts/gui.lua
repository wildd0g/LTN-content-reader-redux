-- GUI Module
-- Handles custom GUI for LTN Content Reader entities

local entity_tracker = require("scripts/entity-tracker")
local ltn_interface = require("scripts/ltn-interface")

local gui = {}

-- Constants
local UPDATE_INTERVAL = 60  -- Update GUI every 60 ticks (1 second)
local GRID_COLUMNS = 10  -- Number of icons per row in the grid
local SIGNAL_MAX = 2147483647
local SIGNAL_MIN = -2147483648

-- GUI element names (constants to avoid typos)
local GUI_MAIN_FRAME = "ltn_reader_main_frame"
local GUI_ALL_NETWORKS_CHECKBOX = "ltn_reader_all_networks_checkbox"
local GUI_NETWORK_ID_TEXTFIELD = "ltn_reader_network_id_textfield"
local GUI_EXACT_NETWORK_CHECKBOX = "ltn_reader_exact_network_checkbox"
local GUI_ALL_SURFACES_CHECKBOX = "ltn_reader_all_surfaces_checkbox"
local GUI_SURFACE_ID_TEXTFIELD = "ltn_reader_surface_idx_textfield"
local GUI_PROVIDER_CHECKBOX = "ltn_reader_provider_checkbox"
local GUI_DELIVER_CHECKBOX = "ltn_reader_deliver_checkbox"
local GUI_REQUESTER_CHECKBOX = "ltn_reader_requester_checkbox"
local GUI_CONTENTS_SCROLL = "ltn_reader_contents_scroll"
local GUI_CONTENTS_TABLE_PROVIDED = "ltn_reader_contents_table_provided"
local GUI_CONTENTS_TABLE_DELIVERING = "ltn_reader_contents_table_delivering"
local GUI_CONTENTS_TABLE_REQUESTED = "ltn_reader_contents_table_requested"
local GUI_REFRESH_BUTTON = "ltn_reader_refresh_button"


-- Parse item string format "type,name"
local function parse_item_string(item_string)
  local item_type, item_name = string.match(item_string, "([^,]+),([^,]+)")
  return item_type, item_name
end

-- Format number with thousand separators
local function format_number(number)
  local sign = ""
  if number > 0 then
    sign = "+"
  elseif number < 0 then
    sign = "-"
    number = math.abs(number)
  end

  -- Convert to string and add thousand separators
  local str = tostring(number)
  local formatted = str:reverse():gsub("(%d%d%d)", "%1,"):reverse()

  -- Remove leading comma if present
  if formatted:sub(1, 1) == "," then
    formatted = formatted:sub(2)
  end

  return sign .. formatted
end

local function populate_grid(contents_table, network_id, surface_idx, content_type, exact_network)
  items = ltn_interface.get_network_data(network_id, surface_idx, content_type, exact_network)

  -- Sort items by name for consistent display
  local sorted_items = {}
  for item_string, count in pairs(items) do
    table.insert(sorted_items, {item = item_string, count = count or 0})
  end
  table.sort(sorted_items, function(a, b)
    return a.item < b.item
  end)

  local button_style = "slot_button"
  -- Determine style based on content_type count
  if content_type == "ltn_provided" or content_type == "p" then
    button_style = "ltn_reader_slot_blue"
  elseif content_type == "ltn_deliveries" or content_type == "d" then
    button_style = "ltn_reader_slot_green"
  elseif content_type == "ltn_requested" or content_type == "r" then
    button_style = "ltn_reader_slot_red"
  end
  
  -- Populate grid with item icons
  local item_count = 0
  for _, data in ipairs(sorted_items) do
    local item_type, item_name = parse_item_string(data.item)

    if item_type and item_name then
      -- Validate prototype exists
      local proto = nil
      if item_type == "item" and prototypes.item[item_name] then
        proto = prototypes.item[item_name]
      elseif item_type == "fluid" and prototypes.fluid[item_name] then
        proto = prototypes.fluid[item_name]
      end

      if proto then
        item_count = item_count + 1

        -- Create tooltip with item name and formatted count
        local formatted_count = format_number(data.count)
        local tooltip_text = proto.localised_name
        if type(tooltip_text) == "table" then
          tooltip_text = {"", tooltip_text, "\n", formatted_count}
        else
          tooltip_text = tooltip_text .. "\n" .. formatted_count
        end

        -- Icon button with count and colored background (enabled so it's not grayed out)
        contents_table.add({
          type = "sprite-button",
          sprite = item_type .. "/" .. item_name,
          number = math.abs(data.count),
          tooltip = tooltip_text,
          style = button_style
        })
      end
    end
  end
  return item_count
end

-- Helper function to find entity by unit number
local function find_entity_by_unit_number(unit_number)
  if not storage.content_readers then
    return nil
  end

  for _, reader in pairs(storage.content_readers) do
    if reader.valid and reader.unit_number == unit_number then
      return reader
    end
  end

  return nil
end

-- Helper function to find GUI element by name recursively
local function find_gui_element(parent, element_name)
  if not parent or not parent.valid then
    return nil
  end

  -- Check direct children
  if parent[element_name] then
    return parent[element_name]
  end

  -- Search recursively through all children
  for _, child in pairs(parent.children) do
    if child.valid then
      if child.name == element_name then
        return child
      end
      -- Recursively search in this child
      local found = find_gui_element(child, element_name)
      if found then
        return found
      end
    end
  end

  return nil
end

-- Update the network contents display
local function update_contents_display(main_frame, entity)
  if not main_frame or not main_frame.valid then
    return
  end

  local contents_table_provide = find_gui_element(main_frame, GUI_CONTENTS_TABLE_PROVIDED)
  if not contents_table_provide or not contents_table_provide.valid then
    return
  end

  local contents_table_deliver = find_gui_element(main_frame, GUI_CONTENTS_TABLE_DELIVERING)
  if not contents_table_deliver or not contents_table_deliver.valid then
    return
  end

  local contents_table_request = find_gui_element(main_frame, GUI_CONTENTS_TABLE_REQUESTED)
  if not contents_table_request or not contents_table_request.valid then
    return
  end

  -- Clear existing contents
  contents_table_provide.clear()
  contents_table_deliver.clear()
  contents_table_request.clear()
  
  -- Get reader state
  local state = entity_tracker.get_reader_state(entity)
  if not state then
    return
  end

  --Skip GUI update if none are turned on
  if not (state.provider or state.deliver or state.requester) then
    return
  end

  -- Get network ID from state
  local network_id = state.all_networks and -1 or state.network_id or ltn_interface.get_default_network_id()

  -- Get surface index from state
  local surface_idx = state.all_surfaces and ltn_interface.get_all_surfaces_index() or state.surface_idx or entity.surface.index
  
  local item_count = 0
  if state.provider then
    item_count = item_count + populate_grid(contents_table_provide, network_id, surface_idx, "p", state.exact_network)
  end
  if state.deliver then
    item_count = item_count + populate_grid(contents_table_deliver, network_id, surface_idx, "d", state.exact_network)
  end
  if state.requester then
    item_count = item_count + populate_grid(contents_table_request, network_id, surface_idx, "r", state.exact_network)
  end

  -- local provide_items = {}
  -- local deliver_items = {}
  -- local request_items = {}
  -- local items = {}  
  -- if state.provider then
  --   provide_items = ltn_interface.get_network_data(network_id, surface_idx, "p", state.exact_network)
  --   for item_string, count in pairs(provide_items) do
  --     items[item_string] = (items[item_string] or 0) + count
  --   end
  -- end
  -- if state.deliver then
  --   deliver_items = ltn_interface.get_network_data(network_id, surface_idx, "d", state.exact_network)
  --   for item_string, count in pairs(deliver_items) do
  --     items[item_string] = (items[item_string] or 0) + count
  --   end
  -- end
  -- if state.requester then
  --   request_items = ltn_interface.get_network_data(network_id, surface_idx, "r", state.exact_network)
  --   for item_string, count in pairs(request_items) do
  --     items[item_string] = (items[item_string] or 0) + count
  --   end
  -- end

  -- -- Sort items by name for consistent display
  -- local sorted_items = {}
  -- for item_string, count in pairs(items) do
  --   table.insert(sorted_items, {item = item_string, count = count})
  -- end
  -- table.sort(sorted_items, function(a, b)
  --   return a.item < b.item
  -- end)

  -- -- Populate grid with item icons
  -- local item_count = 0
  -- for _, data in ipairs(sorted_items) do
  --   local item_type, item_name = parse_item_string(data.item)

  --   if item_type and item_name then
  --     -- Validate prototype exists
  --     local proto = nil
  --     if item_type == "item" and prototypes.item[item_name] then
  --       proto = prototypes.item[item_name]
  --     elseif item_type == "fluid" and prototypes.fluid[item_name] then
  --       proto = prototypes.fluid[item_name]
  --     end

  --     if proto then
  --       item_count = item_count + 1

  --       -- Create tooltip with item name and formatted count
  --       local formatted_count = format_number(data.count)
  --       local tooltip_text = proto.localised_name
  --       if type(tooltip_text) == "table" then
  --         tooltip_text = {"", tooltip_text, "\n", formatted_count}
  --       else
  --         tooltip_text = tooltip_text .. "\n" .. formatted_count
  --       end

  --       -- Determine style based on positive/negative count
  --       local button_style = "slot_button"
  --       if data.count > 0 then
  --         button_style = "ltn_reader_slot_green"  -- Green for positive (provided/surplus)
  --       elseif data.count < 0 then
  --         button_style = "ltn_reader_slot_red"  -- Red for negative (requested/deficit)
  --       end

  --       -- Icon button with count and colored background (enabled so it's not grayed out)
  --       contents_table.add({
  --         type = "sprite-button",
  --         sprite = item_type .. "/" .. item_name,
  --         number = math.abs(data.count),
  --         tooltip = tooltip_text,
  --         style = button_style
  --       })
  --     end
  --   end
  -- end

  -- Show message if no items
  if item_count == 0 then
    local empty_label = contents_table_provide.add({
      type = "label",
      caption = {"ltn-reader.no-items"}
    })
    empty_label.style.font_color = {r = 0.7, g = 0.7, b = 0.7}
  end
end

-- Create the reader GUI for a player
function gui.create_reader_gui(player, entity)
  -- Close any existing GUI
  gui.close_reader_gui(player)

  -- Get current state for this entity
  local reader_state = entity_tracker.get_reader_state(entity)
  if not reader_state then
    return
  end

  -- Create main frame
  local main_frame = player.gui.screen.add({
    type = "frame",
    name = GUI_MAIN_FRAME,
    direction = "vertical",
    caption = {"ltn-reader.gui-title"}
  })
  main_frame.auto_center = true

  -- Store entity reference in the frame tags
  main_frame.tags = {
    entity_unit_number = entity.unit_number
  }

  -- Track that this player has a GUI open
  storage.open_guis = storage.open_guis or {}
  storage.open_guis[player.index] = entity.unit_number

  -- Update tick handler registration
  if register_tick_handler then
    register_tick_handler()
  end

  -- Create title bar with close button
  local title_flow = main_frame.add({
    type = "flow",
    direction = "horizontal"
  })
  title_flow.style.horizontal_spacing = 8

  title_flow.add({
    type = "label",
    caption = {"ltn-reader.gui-subtitle"},
    style = "frame_title"
  })

  local pusher = title_flow.add({
    type = "empty-widget",
    style = "draggable_space_header"
  })
  pusher.style.horizontally_stretchable = true
  pusher.style.height = 24
  pusher.drag_target = main_frame

  title_flow.add({
    type = "sprite-button",
    name = "ltn_reader_close_button",
    sprite = "utility/close",
    style = "frame_action_button",
    mouse_button_filter = {"left"}
  })

  -- Create content area
  local content_frame = main_frame.add({
    type = "frame",
    direction = "vertical",
    style = "inside_shallow_frame_with_padding"
  })

  -- Network ID section
  local network_flow = content_frame.add({
    type = "flow",
    direction = "horizontal"
  })
  network_flow.style.vertical_align = "center"
  network_flow.style.horizontal_spacing = 8

  -- "All Networks" checkbox
  network_flow.add({
    type = "checkbox",
    name = GUI_ALL_NETWORKS_CHECKBOX,
    caption = {"ltn-reader.all-networks-label"},
    state = (reader_state.all_networks == true)
  })

  network_flow.add({
    type = "label",
    caption = {"ltn-reader.network-id-label"}
  })

  local network_textfield = network_flow.add({
    type = "textfield",
    name = GUI_NETWORK_ID_TEXTFIELD,
    text = tostring(reader_state.network_id or 1),
    numeric = true,
    allow_decimal = false,
    allow_negative = true, --Negative network IDs are a thing
    enabled = (reader_state.all_networks == false)
  })
  network_textfield.style.width = 100
  
  -- "Exact Network" checkbox
  network_flow.add({
    type = "checkbox",
    name = GUI_EXACT_NETWORK_CHECKBOX,
    caption = {"ltn-reader.exact-network-label"},
    state = (reader_state.exact_network == true)
  })


  -- Surface IDx section
  local surface_flow = content_frame.add({
    type = "flow",
    direction = "horizontal"
  })
  surface_flow.style.vertical_align = "center"
  surface_flow.style.horizontal_spacing = 8

  -- "All Surfaces" checkbox
  surface_flow.add({
    type = "checkbox",
    name = GUI_ALL_SURFACES_CHECKBOX,
    caption = {"ltn-reader.all-networks-label"},
    state = (reader_state.all_surfaces == true)
  })

  surface_flow.add({
    type = "label",
    caption = {"ltn-reader.surface-id-label"}
  })

  local surface_textfield = surface_flow.add({
    type = "textfield",
    name = GUI_SURFACE_ID_TEXTFIELD,
    text = tostring(reader_state.surface_idx or entity.surface.index),
    numeric = true,
    allow_decimal = false,
    allow_negative = false, --negative surfaces shouldn't exist
    enabled = (reader_state.all_surfaces == false)
  })
  surface_textfield.style.width = 100

  surface_flow.add({
    type = "label",
    caption = {"ltn-reader.current-surface-id-label"}
  })

  local current_surface_textfield = surface_flow.add({
    type = "textfield",
    name = GUI_CURRENT_SURFACE_ID_TEXTFIELD,
    text = entity.surface.index,
    numeric = true,
    allow_decimal = false,
    allow_negative = false, 
    enabled = false
  })
  current_surface_textfield.style.width = 100

  

  -- Add spacing
  content_frame.add({
    type = "line",
    direction = "horizontal"
  })

  -- Add checkboxes
  local checkbox_flow = content_frame.add({
    type = "flow",
    direction = "vertical"
  })
  checkbox_flow.style.vertical_spacing = 8

  -- Provider checkbox
  checkbox_flow.add({
    type = "checkbox",
    name = GUI_PROVIDER_CHECKBOX,
    caption = {"ltn-reader.provider-label"},
    state = reader_state.provider or false
  })

  -- Deliverer checkbox
  checkbox_flow.add({
    type = "checkbox",
    name = GUI_DELIVER_CHECKBOX,
    caption = {"ltn-reader.deliver-label"},
    state = reader_state.deliver or false
  })

  -- Requester checkbox
  checkbox_flow.add({
    type = "checkbox",
    name = GUI_REQUESTER_CHECKBOX,
    caption = {"ltn-reader.requester-label"},
    state = reader_state.requester or false
  })

  -- Add spacing
  content_frame.add({
    type = "line",
    direction = "horizontal"
  })

  -- Network contents section header with refresh button
  local contents_header_flow = content_frame.add({
    type = "flow",
    direction = "horizontal"
  })
  contents_header_flow.style.vertical_align = "center"
  contents_header_flow.style.bottom_margin = 4

  local contents_label = contents_header_flow.add({
    type = "label",
    caption = {"ltn-reader.network-contents-label"},
    style = "caption_label"
  })
  contents_label.style.font = "default-bold"

  local spacer = contents_header_flow.add({
    type = "empty-widget"
  })
  spacer.style.horizontally_stretchable = true

  contents_header_flow.add({
    type = "sprite-button",
    name = GUI_REFRESH_BUTTON,
    sprite = "utility/refresh",
    style = "tool_button",
    tooltip = {"ltn-reader.refresh-tooltip"}
  })

  -- Scrollable contents area
  local contents_scroll = content_frame.add({
    type = "scroll-pane",
    name = GUI_CONTENTS_SCROLL,
    horizontal_scroll_policy = "never",
    vertical_scroll_policy = "auto"
  })
  contents_scroll.style.maximal_height = 400
  contents_scroll.style.minimal_height = 200

  -- Add spacing
  contents_scroll.add({
    type = "line",
    direction = "horizontal"
  })

  -- Table for items (grid layout)
  local contents_table_request = contents_scroll.add({
    type = "table",
    name = GUI_CONTENTS_TABLE_PROVIDED,
    column_count = GRID_COLUMNS
  })
  contents_table_request.style.horizontal_spacing = 0
  contents_table_request.style.vertical_spacing = 0

  -- Table for items (grid layout)
  local contents_table_deliver = contents_scroll.add({
    type = "table",
    name = GUI_CONTENTS_TABLE_DELIVERING,
    column_count = GRID_COLUMNS
  })
  contents_table_deliver.style.horizontal_spacing = 0
  contents_table_deliver.style.vertical_spacing = 0

  -- Table for items (grid layout)
  local contents_table_provide = contents_scroll.add({
    type = "table",
    name = GUI_CONTENTS_TABLE_REQUESTED,
    column_count = GRID_COLUMNS
  })
  contents_table_provide.style.horizontal_spacing = 0
  contents_table_provide.style.vertical_spacing = 0

  -- Populate initial contents
  update_contents_display(main_frame, entity)

  player.opened = main_frame
end

-- Close the reader GUI for a player
function gui.close_reader_gui(player)
  local gui_element = player.gui.screen[GUI_MAIN_FRAME]
  if gui_element then
    gui_element.destroy()
  end

  -- Remove from tracking
  if storage.open_guis then
    storage.open_guis[player.index] = nil

    -- Update tick handler registration
    if register_tick_handler then
      register_tick_handler()
    end
  end
end

-- Handle GUI opened event
function gui.on_gui_opened(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  local entity = event.entity
  if not entity or not entity.valid then
    return
  end

  -- Check if it's our reader entity
  if entity.name == "ltn-content-reader" then
    -- Create our custom GUI (this will automatically override the default entity GUI)
    gui.create_reader_gui(player, entity)
  end
end

-- Handle GUI closed event
function gui.on_gui_closed(event)
  if event.element and event.element.name == GUI_MAIN_FRAME then
    local player = game.get_player(event.player_index)
    if player then
      gui.close_reader_gui(player)
    end
  end
end

-- Handle GUI click event
function gui.on_gui_click(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  local element = event.element
  if not element or not element.valid then
    return
  end

  -- Get main frame
  local main_frame = player.gui.screen[GUI_MAIN_FRAME]

  -- Handle close button
  if element.name == "ltn_reader_close_button" then
    gui.close_reader_gui(player)

  -- Handle refresh button
  elseif element.name == GUI_REFRESH_BUTTON then
    if main_frame and main_frame.valid then
      local unit_number = main_frame.tags.entity_unit_number
      if unit_number then
        -- Find entity using helper function
        local entity = find_entity_by_unit_number(unit_number)

        -- Refresh contents display
        if entity then
          update_contents_display(main_frame, entity)
          player.print({"ltn-reader.refreshed"})
        end
      end
    end
  end
end

-- Handle checkbox state changed event
function gui.on_gui_checked_state_changed(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  local element = event.element
  if not element or not element.valid then
    return
  end

  -- Get the main frame to access entity reference
  local main_frame = player.gui.screen[GUI_MAIN_FRAME]
  if not main_frame then
    return
  end

  local unit_number = main_frame.tags.entity_unit_number
  if not unit_number then
    return
  end

  -- Find the entity using helper function
  local entity = find_entity_by_unit_number(unit_number)
  if not entity then
    return
  end

  -- Get current state
  local state = entity_tracker.get_reader_state(entity)
  if not state then
    return
  end

  -- Helper function to refresh contents display
  local function refresh_contents()
      update_contents_display(main_frame, entity)
  end

  -- Update state based on which checkbox was changed
  if element.name == GUI_PROVIDER_CHECKBOX then
    local new_state = state
    new_state.provider = element.state
    entity_tracker.update_reader_state(entity, new_state)
    refresh_contents()
  elseif element.name == GUI_DELIVER_CHECKBOX then
    local new_state = state
    new_state.deliver = element.state
    entity_tracker.update_reader_state(entity, new_state)
    refresh_contents()
  elseif element.name == GUI_REQUESTER_CHECKBOX then
    local new_state = state
    new_state.requester = element.state
    entity_tracker.update_reader_state(entity, new_state)
    refresh_contents()

  elseif element.name == GUI_ALL_NETWORKS_CHECKBOX then
    -- Find the network ID textfield by searching through GUI elements
    local network_textfield = nil
    for _, child in pairs(main_frame.children) do
      if child.valid and child[GUI_NETWORK_ID_TEXTFIELD] then
        network_textfield = child[GUI_NETWORK_ID_TEXTFIELD]
        break
      end
      -- Also check nested children (flows)
      if child.valid and child.children then
        for _, nested_child in pairs(child.children) do
          if nested_child.valid and nested_child[GUI_NETWORK_ID_TEXTFIELD] then
            network_textfield = nested_child[GUI_NETWORK_ID_TEXTFIELD]
            break
          end
        end
      end
    end

    if network_textfield and network_textfield.valid then
      local network_id = math.floor(tonumber(network_textfield.text) or 1)
      if element.state then
        -- "All Networks" checked: set to -1 and disable textfield
        entity_tracker.set_network_id(entity, network_id, true)
        network_textfield.enabled = false
      else
        -- "All Networks" unchecked: enable textfield and set to its value
        entity_tracker.set_network_id(entity, network_id, false)
        network_textfield.enabled = true
      end
    end
    refresh_contents()

  elseif element.name == GUI_EXACT_NETWORK_CHECKBOX then
  local new_state = state
  new_state.exact_network = element.state
  entity_tracker.update_reader_state(entity, new_state)
  refresh_contents()

  elseif element.name == GUI_ALL_SURFACES_CHECKBOX then
    -- Find the surface IDx textfield by searching through GUI elements
    local surface_textfield = nil
    for _, child in pairs(main_frame.children) do
      if child.valid and child[GUI_SURFACE_ID_TEXTFIELD] then
        surface_textfield = child[GUI_SURFACE_ID_TEXTFIELD]
        break
      end
      -- Also check nested children (flows)
      if child.valid and child.children then
        for _, nested_child in pairs(child.children) do
          if nested_child.valid and nested_child[GUI_SURFACE_ID_TEXTFIELD] then
            surface_textfield = nested_child[GUI_SURFACE_ID_TEXTFIELD]
            break
          end
        end
      end
    end

     if surface_textfield and surface_textfield.valid then
      local surface_idx = math.floor(tonumber(surface_textfield.text) or 1)
      if element.state then
        -- "All Surfaces" checked: disable textfield
        entity_tracker.set_surface_idx(entity, surface_idx, true)
        surface_textfield.enabled = false
      else
        -- "All Surfaces" unchecked: enable textfield and set to its value
        entity_tracker.set_surface_idx(entity, surface_idx, false)
        surface_textfield.enabled = true
      end
    end
    refresh_contents()
  end
end

-- Handle textfield text changed event
function gui.on_gui_text_changed(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  local element = event.element
  if not element or not element.valid then
    return
  end

  -- Get the main frame to access entity reference
  local main_frame = player.gui.screen[GUI_MAIN_FRAME]
  if not main_frame then
    return
  end


  local unit_number = main_frame.tags.entity_unit_number
  if not unit_number then
    return
  end

  -- Find the entity using helper function
  local entity = find_entity_by_unit_number(unit_number)
  if not entity then
    return
  end

  -- Only handle network ID textfield
  if element.name == GUI_NETWORK_ID_TEXTFIELD then
     -- Parse and validate network ID
    local network_id = tonumber(element.text)
    if network_id ~= nil then
      -- Clamp value on valid input
      if network_id > SIGNAL_MAX then network_id = SIGNAL_MAX end
      if network_id < SIGNAL_MIN then network_id = SIGNAL_MIN end
      network_id = math.floor(network_id)
      element.text = tostring(network_id)
      
      -- Update network ID in state
      entity_tracker.set_network_id(entity, network_id, false)

      -- Refresh contents display
      local player_main_frame = player.gui.screen[GUI_MAIN_FRAME]
      if player_main_frame and player_main_frame.valid then
        update_contents_display(player_main_frame, entity)
      end
    else
      -- Invalid input does not apply changes from last valid input, so will reset on re-opening gui
    end
  elseif element.name == GUI_SURFACE_ID_TEXTFIELD then
     -- Parse and validate network ID
    local surface_idx = tonumber(element.text)
    if surface_idx ~= nil then
      -- Clamp value on valid input
      if surface_idx > SIGNAL_MAX then surface_idx = SIGNAL_MAX end
      if surface_idx < SIGNAL_MIN then surface_idx = SIGNAL_MIN end
      surface_idx = math.floor(surface_idx)
      element.text = tostring(surface_idx)
      
      -- Update network ID in state
      entity_tracker.set_surface_idx(entity, surface_idx, false)

      -- Refresh contents display
      local player_main_frame = player.gui.screen[GUI_MAIN_FRAME]
      if player_main_frame and player_main_frame.valid then
        update_contents_display(player_main_frame, entity)
      end
    else
      -- Invalid input does not apply changes from last valid input, so will reset on re-opening gui
    end

  else
    -- Nothing to change, unknown text field
  end
  

end

-- Handle tick event for real-time GUI updates
function gui.on_tick(event)
  -- Only update every UPDATE_INTERVAL ticks
  if event.tick % UPDATE_INTERVAL ~= 0 then
    return
  end

  -- Check if we have any open GUIs
  if not storage.open_guis then
    return
  end

  -- Update each open GUI
  for player_index, unit_number in pairs(storage.open_guis) do
    local player = game.get_player(player_index)

    if player and player.valid then
      local main_frame = player.gui.screen[GUI_MAIN_FRAME]

      if main_frame and main_frame.valid then
        -- Find the entity
        local entity = find_entity_by_unit_number(unit_number)

        if entity then
          -- Update the contents display
            update_contents_display(main_frame, entity)
        else
          -- Entity no longer exists, close GUI
          gui.close_reader_gui(player)
        end
      else
        -- GUI closed by user, clean up tracking
        storage.open_guis[player_index] = nil
      end
    else
      -- Player no longer exists, clean up tracking
      storage.open_guis[player_index] = nil
    end
  end
end

return gui
