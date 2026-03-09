-- Liminal Salt — Neovim colorscheme
-- https://github.com/irvj/liminal-salt

local M = {}

function M.load()
  if vim.g.colors_name then
    vim.cmd("hi clear")
  end
  if vim.fn.exists("syntax_on") then
    vim.cmd("syntax reset")
  end

  vim.o.termguicolors = true
  vim.o.background = "dark"
  vim.g.colors_name = "liminal-salt-dark"

  -- Collect all highlight groups
  local groups = {}
  local modules = {
    require("liminal-salt.editor"),
    require("liminal-salt.syntax"),
    require("liminal-salt.treesitter"),
    require("liminal-salt.lsp"),
    require("liminal-salt.plugins.gitsigns"),
    require("liminal-salt.plugins.snacks"),
  }

  for _, mod in ipairs(modules) do
    for name, hl in pairs(mod.highlights()) do
      groups[name] = hl
    end
  end

  -- Apply all highlights
  for name, hl in pairs(groups) do
    vim.api.nvim_set_hl(0, name, hl)
  end

  -- Apply terminal colors
  require("liminal-salt.terminal").apply()
end

return M
