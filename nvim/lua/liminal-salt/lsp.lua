-- Liminal Salt — LSP and diagnostic highlights
local p = require("liminal-salt.palette").p

local M = {}

function M.highlights()
  return {
    -- Diagnostics
    DiagnosticError          = { fg = p.red400 },
    DiagnosticWarn           = { fg = p.amber400 },
    DiagnosticInfo           = { fg = p.sage400 },
    DiagnosticHint           = { fg = p.sage400 },
    DiagnosticOk             = { fg = p.sage500 },

    -- Virtual text
    DiagnosticVirtualTextError = { fg = p.red400 },
    DiagnosticVirtualTextWarn  = { fg = p.amber400 },
    DiagnosticVirtualTextInfo  = { fg = p.sage400 },
    DiagnosticVirtualTextHint  = { fg = p.sage400 },
    DiagnosticVirtualTextOk   = { fg = p.sage500 },

    -- Underline
    DiagnosticUnderlineError = { undercurl = true, sp = p.red400 },
    DiagnosticUnderlineWarn  = { undercurl = true, sp = p.amber400 },
    DiagnosticUnderlineInfo  = { undercurl = true, sp = p.sage400 },
    DiagnosticUnderlineHint  = { undercurl = true, sp = p.sage400 },
    DiagnosticUnderlineOk    = { undercurl = true, sp = p.sage500 },

    -- Sign
    DiagnosticSignError = { fg = p.red400 },
    DiagnosticSignWarn  = { fg = p.amber400 },
    DiagnosticSignInfo  = { fg = p.sage400 },
    DiagnosticSignHint  = { fg = p.sage400 },
    DiagnosticSignOk    = { fg = p.sage500 },

    -- LSP references
    LspReferenceText  = { bg = p.sageTint30 },
    LspReferenceRead  = { bg = p.sageTint30 },
    LspReferenceWrite = { bg = p.sageTint30 },

    -- LSP inlay hints
    LspInlayHint = { fg = p.beige600, italic = true },

    -- LSP code lens
    LspCodeLens          = { fg = p.beige600 },
    LspCodeLensSeparator = { fg = p.stone50 },

    -- LSP signature
    LspSignatureActiveParameter = { bg = p.sageTint30, bold = true },
  }
end

return M
