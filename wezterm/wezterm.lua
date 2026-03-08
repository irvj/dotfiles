local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.font = wezterm.font 'JetBrainsMono Nerd Font'
config.font_size = 14.0
config.default_prog = { 'wsl.exe', '-d', 'jdev' }
config.hide_tab_bar_if_only_one_tab = true
config.window_close_confirmation = 'NeverPrompt'
config.window_padding = { left = 8, right = 8, top = 8, bottom = 8 }
config.front_end = 'WebGpu'
config.webgpu_power_preference = 'HighPerformance'

config.colors = {
  foreground = '#e8e4dc',
  background = '#1a1c1b',
  cursor_bg = '#8fac98',
  cursor_fg = '#1a1c1b',
  cursor_border = '#8fac98',
  selection_bg = '#3d4741',
  selection_fg = '#e8e4dc',
  scrollbar_thumb = '#2e312f',
  split = '#2e312f',
  compose_cursor = '#c9a86c',
  ansi = {
    '#141615', '#cc8585', '#7dba8a', '#c9a86c',
    '#7eb8c9', '#c9956c', '#95bebe', '#c5c1b8',
  },
  brights = {
    '#6b7369', '#d99292', '#a3bfac', '#c9a86c',
    '#7eb8c9', '#c9956c', '#95bebe', '#e8e4dc',
  },
  tab_bar = {
    background = '#242726',
    active_tab = { bg_color = '#1a1c1b', fg_color = '#e8e4dc', intensity = 'Bold' },
    inactive_tab = { bg_color = '#242726', fg_color = '#9e9b93' },
    inactive_tab_hover = { bg_color = '#141615', fg_color = '#e8e4dc', italic = true },
    new_tab = { bg_color = '#242726', fg_color = '#9e9b93' },
    new_tab_hover = { bg_color = '#8fac98', fg_color = '#1a1c1b' },
  },
}

return config
