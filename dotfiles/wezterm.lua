local wezterm = require 'wezterm'

local config = {}

config.ssh_domains = {
  {
    name = 'protagonism',
    remote_address = 'protagonism'
  },
}
config.unix_domains = {
  {
    name = 'unix',
  }
}

config.font = wezterm.font "Fira Code"
config.font_size = 10

return config
