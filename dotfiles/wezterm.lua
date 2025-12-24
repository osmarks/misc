local wezterm = require 'wezterm'

local config = {}

config.ssh_domains = {
  {
    name = 'straylight',
    remote_address = 'straylight'
  },
}
config.unix_domains = {
  {
    name = 'unix',
  }
}

config.font = wezterm.font "Fira Code"
config.font_size = 10
config.font_rules = {
    {
        intensity = "Half",
        font = wezterm.font("Fira Code", { weight = "Regular" })
    }
}

return config
