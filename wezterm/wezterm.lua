local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.font = wezterm.font 'MesloLGS Nerd Font'
config.font_size = 14.0
config.color_scheme = 'Nord (Gogh)'
config.default_prog = { 'wsl.exe', '-d', 'jdev' }
config.hide_tab_bar_if_only_one_tab = true
config.window_close_confirmation = 'NeverPrompt'
config.window_padding = { left = 8, right = 8, top = 8, bottom = 8 }
config.front_end = 'WebGpu'
config.webgpu_power_preference = 'HighPerformance'

return config
