---@diagnostic disable: undefined-global
return {
  {
    "lewis6991/gitsigns.nvim",
    enabled = true,
    opts = {
      current_line_blame = true,
    },
    config = function(_, opts)
      require("gitsigns").setup(opts)

      vim.api.nvim_create_autocmd("FocusGained", {
        group = vim.api.nvim_create_augroup("gitsigns_refresh", { clear = true }),
        callback = function()
          vim.defer_fn(function()
            if not package.loaded["gitsigns"] then
              return
            end
            local gs = require("gitsigns")
            gs.detach_all()
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
              if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
                pcall(gs.attach, buf)
              end
            end
          end, 100)
        end,
      })
    end,
  },
}
