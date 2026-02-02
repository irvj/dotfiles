return {
  {
    "lewis6991/gitsigns.nvim",
    enabled = true,
    opts = {
      current_line_blame = true,
    },
    config = function(_, opts)
      require("gitsigns").setup(opts)

      vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "TermClose", "TermLeave" }, {
        group = vim.api.nvim_create_augroup("gitsigns_refresh", { clear = true }),
        callback = function()
          vim.defer_fn(function()
            if package.loaded["gitsigns"] then
              require("gitsigns").refresh()
            end
          end, 100)
        end,
      })
    end,
  },
}
