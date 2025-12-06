-- GUI Styles for LTN Content Reader
-- Defines colored slot button styles for the network contents display

local styles = data.raw["gui-style"].default

-- Red background style for requests (requested/deficit items)
styles.ltn_reader_slot_red = {
  type = "button_style",
  parent = "slot_button",
  default_graphical_set = {
    base = {
      position = {0, 0},
      corner_size = 8,
      center = {position = {42, 8}, size = {1, 1}},
      tint = {r = 1.0, g = 0.0, b = 0.0, a = 0.9},
      draw_type = "inner"
    },
    shadow = {
      position = {440, 24},
      corner_size = 8,
      draw_type = "outer"
    }
  },
  hovered_graphical_set = {
    base = {
      position = {0, 0},
      corner_size = 8,
      center = {position = {42, 8}, size = {1, 1}},
      tint = {r = 1.0, g = 0.2, b = 0.2, a = 1.0},
      draw_type = "inner"
    },
    shadow = {
      position = {440, 24},
      corner_size = 8,
      draw_type = "outer"
    }
  },
  clicked_graphical_set = {
    base = {
      position = {0, 0},
      corner_size = 8,
      center = {position = {42, 8}, size = {1, 1}},
      tint = {r = 0.8, g = 0.0, b = 0.0, a = 1.0},
      draw_type = "inner"
    },
    shadow = {
      position = {440, 24},
      corner_size = 8,
      draw_type = "outer"
    }
  }
}

-- Green background style for deliveries
styles.ltn_reader_slot_green = {
  type = "button_style",
  parent = "slot_button",
  default_graphical_set = {
    base = {
      position = {0, 0},
      corner_size = 8,
      center = {position = {42, 8}, size = {1, 1}},
      tint = {r = 0.0, g = 1.0, b = 0.0, a = 0.9},
      draw_type = "inner"
    },
    shadow = {
      position = {440, 24},
      corner_size = 8,
      draw_type = "outer"
    }
  },
  hovered_graphical_set = {
    base = {
      position = {0, 0},
      corner_size = 8,
      center = {position = {42, 8}, size = {1, 1}},
      tint = {r = 0.2, g = 1.0, b = 0.2, a = 1.0},
      draw_type = "inner"
    },
    shadow = {
      position = {440, 24},
      corner_size = 8,
      draw_type = "outer"
    }
  },
  clicked_graphical_set = {
    base = {
      position = {0, 0},
      corner_size = 8,
      center = {position = {42, 8}, size = {1, 1}},
      tint = {r = 0.0, g = 0.8, b = 0.0, a = 1.0},
      draw_type = "inner"
    },
    shadow = {
      position = {440, 24},
      corner_size = 8,
      draw_type = "outer"
    }
  }
}

-- Blue background style for provided
styles.ltn_reader_slot_blue = {
  type = "button_style",
  parent = "slot_button",
  default_graphical_set = {
    base = {
      position = {0, 0},
      corner_size = 8,
      center = {position = {42, 8}, size = {1, 1}},
      tint = {r = 0.0, g = 0.0, b = 1.0, a = 0.9},
      draw_type = "inner"
    },
    shadow = {
      position = {440, 24},
      corner_size = 8,
      draw_type = "outer"
    }
  },
  hovered_graphical_set = {
    base = {
      position = {0, 0},
      corner_size = 8,
      center = {position = {42, 8}, size = {1, 1}},
      tint = {r = 0.2, g = 0.2, b = 1.0, a = 1.0},
      draw_type = "inner"
    },
    shadow = {
      position = {440, 24},
      corner_size = 8,
      draw_type = "outer"
    }
  },
  clicked_graphical_set = {
    base = {
      position = {0, 0},
      corner_size = 8,
      center = {position = {42, 8}, size = {1, 1}},
      tint = {r = 0.0, g = 0.0, b = 0.8, a = 1.0},
      draw_type = "inner"
    },
    shadow = {
      position = {440, 24},
      corner_size = 8,
      draw_type = "outer"
    }
  }
}


