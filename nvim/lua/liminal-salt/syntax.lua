-- Liminal Salt — syntax highlights
local p = require("liminal-salt.palette").p

local M = {}

function M.highlights()
  return {
    Comment    = { fg = p.beige600, italic = true },
    Constant   = { fg = p.blue400 },
    String     = { fg = p.amber400 },
    Character  = { fg = p.amber400 },
    Number     = { fg = p.blue400 },
    Float      = { fg = p.blue400 },
    Boolean    = { fg = p.blue400 },
    Identifier = { fg = p.beige300 },
    Function   = { fg = p.sage300 },
    Statement  = { fg = p.sage400 },
    Keyword    = { fg = p.sage400 },
    Conditional = { fg = p.sage400 },
    Repeat     = { fg = p.sage400 },
    Label      = { fg = p.sage400 },
    Exception  = { fg = p.sage400 },
    Operator   = { fg = p.beige500 },
    PreProc    = { fg = p.sage400 },
    Include    = { fg = p.sage400 },
    Define     = { fg = p.sage400 },
    Macro      = { fg = p.sage400 },
    Type       = { fg = p.teal500 },
    StorageClass = { fg = p.sage400 },
    Structure  = { fg = p.teal500 },
    Typedef    = { fg = p.teal500 },
    Special    = { fg = p.orange400 },
    SpecialChar = { fg = p.orange400 },
    Tag        = { fg = p.red400 },
    Delimiter  = { fg = p.beige500 },
    Debug      = { fg = p.red400 },
    Todo       = { fg = p.amber400, bold = true },
    Underlined = { fg = p.sage400, underline = true },
    Error      = { fg = p.red400 },
  }
end

return M
