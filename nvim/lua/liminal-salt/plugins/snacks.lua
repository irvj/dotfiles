-- Liminal Salt — snacks.nvim highlights
local p = require("liminal-salt.palette").p

local M = {}

function M.highlights()
  return {
    -- Picker sidebar (surface-secondary for darker sidebar)
    SnacksPickerList        = { fg = p.beige300, bg = p.stone300 },
    SnacksPickerInput       = { fg = p.beige300, bg = p.stone300 },
    SnacksPickerInputBorder = { fg = p.stone50, bg = p.stone300 },
    SnacksPickerBox         = { fg = p.beige300, bg = p.stone300 },
    SnacksPickerBoxBorder   = { fg = p.stone50, bg = p.stone300 },

    -- Picker content
    SnacksPickerDir             = { fg = p.beige600 },
    SnacksPickerTotals          = { fg = p.beige600 },
    SnacksPickerMatch           = { fg = p.sage400, bold = true },
    SnacksPickerBufFlags        = { fg = p.beige600 },
    SnacksPickerPathHidden      = { fg = p.beige600 },
    SnacksPickerPathIgnored     = { fg = p.beige600 },
    SnacksPickerGitStatusIgnored   = { fg = p.beige600 },
    SnacksPickerGitStatusUntracked = { fg = p.sage500 },

    -- Dashboard
    SnacksDashboardDir    = { fg = p.beige600 },
    SnacksDashboardHeader = { fg = p.sage400 },
    SnacksDashboardIcon   = { fg = p.sage400 },
    SnacksDashboardKey    = { fg = p.teal400 },
    SnacksDashboardTitle  = { fg = p.sage400, bold = true },
    SnacksDashboardDesc   = { fg = p.beige500 },

    -- Indent
    SnacksIndent      = { fg = p.stone50 },
    SnacksIndentScope = { fg = p.sage600 },

    -- Notifier
    SnacksNotifierInfo  = { fg = p.sage400 },
    SnacksNotifierWarn  = { fg = p.amber400 },
    SnacksNotifierError = { fg = p.red400 },
  }
end

return M
