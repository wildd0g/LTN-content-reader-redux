data:extend({
  {
    type = "bool-setting",
    name = "ltn_content_reader_global_groups",
    order = "aa",
    setting_type = "runtime-global",
    default_value = false,
  },
  {
    type = "string-setting",
    name = "ltn_content_reader_default_surface",
    order = "ab",
    setting_type = "runtime-global",
    default_value = "current",
    allowed_values = {"all", "current"},
  },
})