-- convert from state in storage based combinators to inactive signalgroup based combinators.
local updater = require("scripts/combinator-updater")

local function state_storage_to_combinator(entity)
  local unit_number = entity.unit_number
  local behaviour = entity.get_or_create_control_behavior()
  while behaviour.sections_count < 2 do
    behaviour.add_section()
  end
  while behaviour.sections_count > 2 do
    behaviour.remove_section(3)
  end
  local settings_section = behaviour.get_section(1)
  settings_section.active = false
  local state = storage.reader_states[unit_number]
  if state.network_id then
    settings_section.set_slot(1, {
      min = state.network_id,
      value = { type = "virtual", name = "ltn-network-id", comparator = "=", quality = "normal" }
    })
  end
  if state.surface_idx then
    settings_section.set_slot(2, {
      min = state.surface_idx,
      value = { type = "virtual", name = "signal-map-marker", comparator = "=", quality = "normal" }
    })
  end
  settings_section.set_slot(3, {
    min = updater.bool_settings_state_to_num(state),
    value = { type = "virtual", name = "signal-check", comparator = "=", quality = "normal" }
  })
  
end

if storage.content_readers and storage.reader_states then
  for i = #storage.content_readers, 1, -1 do
    unit_number = storage.content_readers[i].unit_number
    if storage.reader_states[unit_number] then
      state_storage_to_combinator(storage.content_readers[i])
    end
  end
end

