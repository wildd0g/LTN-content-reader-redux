--[[ Copyright (c) 2018 Optera
 * Part of LTN Content Reader
 *
 * See LICENSE.md in the project directory for license information.
--]]

local flib = require('__flib__.data-util')



local delivery_reader_entity = flib.copy_prototype(data.raw["constant-combinator"]["constant-combinator"], "ltn-content-reader")
delivery_reader_entity.item_slot_count = 50 -- will be overwritten in final-fixes
delivery_reader_entity.icon = "__LTN_Content_Reader_Redux__/graphics/icons/ltn-delivery-reader.png"
delivery_reader_entity.icon_size = 64
delivery_reader_entity.icon_mipmaps = 4
delivery_reader_entity.sprites = make_4way_animation_from_spritesheet(
  { layers =
    {
      {
          scale = 0.5,
          filename = "__LTN_Content_Reader_Redux__/graphics/entity/hr-ltn-delivery-reader.png",
          width = 114,
          height = 102,
          frame_count = 1,
          shift = util.by_pixel(0, 5),
      },
      {
          scale = 0.5,
          filename = "__base__/graphics/entity/combinator/constant-combinator-shadow.png",
          width = 98,
          height = 66,
          frame_count = 1,
          shift = util.by_pixel(8.5, 5.5),
          draw_as_shadow = true,
      },
    },
  })

local delivery_reader_item = flib.copy_prototype(data.raw["item"]["constant-combinator"], "ltn-content-reader")
delivery_reader_item.icon = "__LTN_Content_Reader_Redux__/graphics/icons/ltn-delivery-reader.png"
delivery_reader_item.icon_size = 64
delivery_reader_item.icon_mipmaps = 4
delivery_reader_item.subgroup = "circuit-network-2"
delivery_reader_item.order = "ltnr-c"
-- delivery_reader_item.order = requester_reader_item.order.."d" -- sort after constant_combinator

local delivery_reader_recipe = flib.copy_prototype(data.raw["recipe"]["constant-combinator"], "ltn-content-reader")

data:extend({
  {
    type = "item-subgroup",
    name = "circuit-network-2",
    group = "logistics",
    order = data.raw["item-subgroup"]["circuit-network"].order.."2"
  },
  -- provider_reader_entity,
  -- provider_reader_item,
  -- provider_reader_recipe,
  -- requester_reader_entity,
  -- requester_reader_item,
  -- requester_reader_recipe,
  delivery_reader_entity,
  delivery_reader_item,
  delivery_reader_recipe,
})

-- add to circuit-network-2 if exists otherwise create tech
if data.raw["technology"]["circuit-network-2"] then
  -- table.insert( data.raw["technology"]["circuit-network-2"].effects, { type = "unlock-recipe", recipe = "ltn-provider-reader" } )
  -- table.insert( data.raw["technology"]["circuit-network-2"].effects, { type = "unlock-recipe", recipe = "ltn-requester-reader" } )
  table.insert( data.raw["technology"]["circuit-network-2"].effects, { type = "unlock-recipe", recipe = "ltn-content-reader" } )
else
  data:extend({
    {
      type = "technology",
      name = "circuit-network-2",
      icon = "__base__/graphics/technology/circuit-network.png",
      icon_size = 256, icon_mipmaps = 4,
      prerequisites = {"circuit-network"},
      effects =
      {
        -- { type = "unlock-recipe", recipe = "ltn-provider-reader" },
        -- { type = "unlock-recipe", recipe = "ltn-requester-reader" },
        { type = "unlock-recipe", recipe = "ltn-content-reader" },
      },
      unit =
      {
        count = 150,
        ingredients = {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1},
        },
        time = 30
      },
      order = "a-d-d"
    }
  })
end




