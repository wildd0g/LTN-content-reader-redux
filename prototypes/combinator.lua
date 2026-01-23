--[[ Copyright (c) 2018 Optera
 * Part of LTN Content Reader
 *
 * See LICENSE.md in the project directory for license information.
--]]

local flib = require('__flib__.data-util')



local content_reader_entity = flib.copy_prototype(data.raw["constant-combinator"]["constant-combinator"], "ltn-content-reader")
content_reader_entity.item_slot_count = 50 -- will be overwritten in final-fixes
content_reader_entity.icon = "__LTN_Content_Reader_Redux__/graphics/icons/ltn-content-reader.png"
content_reader_entity.icon_size = 64
content_reader_entity.icon_mipmaps = 4
content_reader_entity.next_upgrade = nil
content_reader_entity.fast_replaceable_group = "constant-combinator"
content_reader_entity.sprites = make_4way_animation_from_spritesheet(
  { layers =
    {
      {
          scale = 0.5,
          filename = "__LTN_Content_Reader_Redux__/graphics/entity/ltn-content-reader.png",
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
  }
)

content_reader_item = flib.copy_prototype(data.raw["item"]["constant-combinator"], "ltn-content-reader")
content_reader_item.icon = "__LTN_Content_Reader_Redux__/graphics/icons/ltn-content-reader.png"
content_reader_item.icon_size = 64
content_reader_item.icon_mipmaps = 4
-- content_reader_item.order = "ltnr-c"
content_reader_item.order = content_reader_item.order.."d" -- sort after constant_combinator

content_reader_recipe = flib.copy_prototype(data.raw["recipe"]["constant-combinator"], "ltn-content-reader")

data:extend({
  content_reader_entity,
  content_reader_item,
  content_reader_recipe,
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




