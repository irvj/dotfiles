-- Liminal Salt — gitsigns highlights
local p = require("liminal-salt.palette").p

local M = {}

function M.highlights()
  return {
    GitSignsAdd          = { fg = p.sage500 },
    GitSignsChange       = { fg = p.amber400 },
    GitSignsDelete       = { fg = p.red400 },
    GitSignsAddNr        = { fg = p.sage500 },
    GitSignsChangeNr     = { fg = p.amber400 },
    GitSignsDeleteNr     = { fg = p.red400 },
    GitSignsAddLn        = { bg = p.greenTint30 },
    GitSignsChangeLn     = { bg = p.beigeTint15 },
    GitSignsDeleteLn     = { bg = p.redTint30 },
    GitSignsCurrentLineBlame = { fg = p.beige600, italic = true },
  }
end

return M
