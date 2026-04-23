return {
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      local cfg = vim.fn.stdpath("config") .. "/markdownlint-cli2.yaml"
      opts.linters = opts.linters or {}
      opts.linters["markdownlint-cli2"] = {
        args = { "--config", cfg, "--" },
      }
      return opts
    end,
  },
}
