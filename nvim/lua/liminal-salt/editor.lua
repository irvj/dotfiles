-- Liminal Salt — editor UI highlights
local p = require("liminal-salt.palette").p

local M = {}

function M.highlights()
  return {
    -- Editor
    Normal       = { fg = p.beige300, bg = p.stone200 },
    NormalNC     = { fg = p.beige300, bg = p.stone200 },
    CursorLine   = { bg = p.beigeTint15 },
    CursorLineNr = { fg = p.beige500, bg = p.beigeTint15 },
    LineNr       = { fg = p.beige600 },
    Visual       = { bg = p.sageTint30 },
    Search       = { bg = p.amberTint30 },
    IncSearch    = { bg = p.amberTint30, bold = true },
    CurSearch    = { bg = p.amberTint30, bold = true },
    MatchParen   = { bg = p.stone50, bold = true },
    NonText      = { fg = p.stone50 },
    SpecialKey   = { fg = p.stone50 },
    Cursor       = { fg = p.stone200, bg = p.sage400 },
    lCursor      = { fg = p.stone200, bg = p.sage400 },
    CursorIM     = { fg = p.stone200, bg = p.sage400 },
    SignColumn   = { fg = p.beige600, bg = p.stone200 },
    FoldColumn   = { fg = p.beige600, bg = p.stone200 },
    Folded       = { fg = p.beige600, bg = p.stone300 },
    ColorColumn  = { bg = p.stone300 },
    Conceal      = { fg = p.beige600 },
    Directory    = { fg = p.sage400 },
    EndOfBuffer  = { fg = p.stone200 },
    WildMenu     = { fg = p.beige300, bg = p.sageTint30 },
    QuickFixLine = { bg = p.sageTint30 },
    Substitute   = { bg = p.amberTint30 },

    -- UI chrome
    StatusLine   = { fg = p.beige300, bg = p.stone100 },
    StatusLineNC = { fg = p.beige600, bg = p.stone100 },
    VertSplit    = { fg = p.stone50, bg = p.stone200 },
    WinSeparator = { fg = p.stone50, bg = p.stone200 },
    TabLine      = { fg = p.beige600, bg = p.stone100 },
    TabLineFill  = { bg = p.stone100 },
    TabLineSel   = { fg = p.beige300, bg = p.stone200, bold = true },
    Title        = { fg = p.sage400, bold = true },

    -- Popup menu
    Pmenu        = { fg = p.beige300, bg = p.stone100 },
    PmenuSel     = { fg = p.beige300, bg = p.sageTint30 },
    PmenuSbar    = { bg = p.stone300 },
    PmenuThumb   = { bg = p.stone50 },

    -- Floating windows
    NormalFloat  = { fg = p.beige300, bg = p.stone100 },
    FloatBorder  = { fg = p.stone50, bg = p.stone100 },
    FloatTitle   = { fg = p.sage400, bg = p.stone100, bold = true },

    -- Messages
    ErrorMsg   = { fg = p.red400, bold = true },
    WarningMsg = { fg = p.amber400 },
    MoreMsg    = { fg = p.sage400 },
    ModeMsg    = { fg = p.beige300, bold = true },
    Question   = { fg = p.sage400 },

    -- Diff
    DiffAdd    = { bg = p.greenTint30 },
    DiffDelete = { bg = p.redTint30 },
    DiffChange = { bg = p.beigeTint15 },
    DiffText   = { bg = p.amberTint30, bold = true },

    -- Spell
    SpellBad  = { undercurl = true, sp = p.red400 },
    SpellCap  = { undercurl = true, sp = p.amber400 },
    SpellLocal = { undercurl = true, sp = p.teal400 },
    SpellRare = { undercurl = true, sp = p.blue400 },
  }
end

return M
