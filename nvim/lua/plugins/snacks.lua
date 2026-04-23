return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          grep = { args = { "--no-messages" } },
          grep_word = { args = { "--no-messages" } },
          grep_buffers = { args = { "--no-messages" } },
        },
      },
    },
  },
}
