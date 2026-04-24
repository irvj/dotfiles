return {
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = { php = {} },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = vim.tbl_filter(function(pkg)
        return pkg ~= "php-cs-fixer"
      end, opts.ensure_installed or {})
    end,
  },
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters = {
        phpcs = {
          args = {
            "--exclude=Generic.Files.LineLength,Generic.WhiteSpace.DisallowTabIndent",
            "-q",
            "--report=json",
            function()
              return "--stdin-path=" .. vim.fn.expand("%:p:.")
            end,
            "-",
          },
        },
      },
    },
  },
}
