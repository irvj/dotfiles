-- Liminal Salt — treesitter highlights
local p = require("liminal-salt.palette").p

local M = {}

function M.highlights()
  return {
    -- Misc
    ["@comment"]               = { link = "Comment" },
    ["@error"]                 = { fg = p.red400 },
    ["@preproc"]               = { fg = p.sage400 },

    -- Punctuation
    ["@punctuation.delimiter"] = { fg = p.beige500 },
    ["@punctuation.bracket"]   = { fg = p.beige500 },
    ["@punctuation.special"]   = { fg = p.beige500 },

    -- Literals
    ["@string"]                = { fg = p.amber400 },
    ["@string.regex"]          = { fg = p.olive400 },
    ["@string.escape"]         = { fg = p.orange400 },
    ["@string.special"]        = { fg = p.orange400 },
    ["@character"]             = { fg = p.amber400 },
    ["@boolean"]               = { fg = p.blue400 },
    ["@number"]                = { fg = p.blue400 },
    ["@float"]                 = { fg = p.blue400 },

    -- Functions
    ["@function"]              = { fg = p.sage300 },
    ["@function.call"]         = { fg = p.sage300 },
    ["@function.builtin"]      = { fg = p.sage300 },
    ["@function.macro"]        = { fg = p.sage400 },
    ["@method"]                = { fg = p.sage300 },
    ["@method.call"]           = { fg = p.sage300 },
    ["@constructor"]           = { fg = p.teal500 },

    -- Keywords
    ["@keyword"]               = { fg = p.sage400 },
    ["@keyword.function"]      = { fg = p.sage400 },
    ["@keyword.operator"]      = { fg = p.sage400 },
    ["@keyword.return"]        = { fg = p.sage400 },
    ["@conditional"]           = { fg = p.sage400 },
    ["@repeat"]                = { fg = p.sage400 },
    ["@label"]                 = { fg = p.sage400 },
    ["@include"]               = { fg = p.sage400 },
    ["@exception"]             = { fg = p.sage400 },

    -- Types
    ["@type"]                  = { fg = p.teal500 },
    ["@type.builtin"]          = { fg = p.teal500 },
    ["@type.qualifier"]        = { fg = p.sage400 },
    ["@type.definition"]       = { fg = p.teal500 },
    ["@storageclass"]          = { fg = p.sage400 },
    ["@attribute"]             = { fg = p.amber400 },
    ["@field"]                 = { fg = p.beige300 },
    ["@property"]              = { fg = p.beige300 },

    -- Identifiers
    ["@variable"]              = { fg = p.beige300 },
    ["@variable.builtin"]      = { fg = p.blue400 },
    ["@constant"]              = { fg = p.blue400 },
    ["@constant.builtin"]      = { fg = p.blue400 },
    ["@constant.macro"]        = { fg = p.blue400 },
    ["@namespace"]             = { fg = p.teal500 },
    ["@module"]                = { fg = p.teal500 },
    ["@symbol"]                = { fg = p.sage400 },

    -- Text / markup
    ["@text"]                  = { fg = p.beige300 },
    ["@text.strong"]           = { bold = true },
    ["@text.emphasis"]         = { italic = true },
    ["@text.underline"]        = { underline = true },
    ["@text.strike"]           = { strikethrough = true },
    ["@text.title"]            = { fg = p.sage400, bold = true },
    ["@text.literal"]          = { fg = p.amber400 },
    ["@text.uri"]              = { fg = p.sage400, underline = true },
    ["@text.todo"]             = { fg = p.amber400, bold = true },
    ["@text.note"]             = { fg = p.sage400, bold = true },
    ["@text.warning"]          = { fg = p.amber400, bold = true },
    ["@text.danger"]           = { fg = p.red400, bold = true },
    ["@text.diff.add"]         = { fg = p.sage500 },
    ["@text.diff.delete"]      = { fg = p.red400 },

    -- Tags
    ["@tag"]                   = { fg = p.red400 },
    ["@tag.attribute"]         = { fg = p.amber400 },
    ["@tag.delimiter"]         = { fg = p.beige500 },

    -- Markup (new treesitter captures)
    ["@markup.heading"]        = { fg = p.sage400, bold = true },
    ["@markup.italic"]         = { italic = true },
    ["@markup.strong"]         = { bold = true },
    ["@markup.raw"]            = { fg = p.amber400 },
    ["@markup.link"]           = { fg = p.sage400, underline = true },
    ["@markup.link.url"]       = { fg = p.amber400, underline = true },
    ["@markup.list"]           = { fg = p.beige500 },
  }
end

return M
