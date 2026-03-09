-- Liminal Salt — terminal colors
local p = require("liminal-salt.palette").p

local M = {}

function M.apply()
  vim.g.terminal_color_0  = p.stone300
  vim.g.terminal_color_1  = p.red400
  vim.g.terminal_color_2  = p.sage500
  vim.g.terminal_color_3  = p.amber400
  vim.g.terminal_color_4  = p.blue400
  vim.g.terminal_color_5  = p.orange400
  vim.g.terminal_color_6  = p.teal400
  vim.g.terminal_color_7  = p.beige500
  vim.g.terminal_color_8  = p.sage600
  vim.g.terminal_color_9  = p.red300
  vim.g.terminal_color_10 = p.sage300
  vim.g.terminal_color_11 = p.amber400
  vim.g.terminal_color_12 = p.blue400
  vim.g.terminal_color_13 = p.orange400
  vim.g.terminal_color_14 = p.teal400
  vim.g.terminal_color_15 = p.beige300
end

return M
