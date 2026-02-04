local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.font = wezterm.font 'MesloLGS Nerd Font'
config.font_size = 14.0
config.color_scheme = 'Nord (Gogh)'
config.front_end = 'WebGpu'
config.webgpu_power_preference = 'HighPerformance'

return config
