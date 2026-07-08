return {
  -- Don't run php-cs-fixer as a formatter.
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = { php = {} },
    },
  },
  -- Don't auto-install the PHP style tools we no longer use.
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      local drop = { ["php-cs-fixer"] = true, phpcs = true }
      opts.ensure_installed = vim.tbl_filter(function(pkg)
        return not drop[pkg]
      end, opts.ensure_installed or {})
    end,
  },
  -- Disable phpcs linting for PHP entirely. It only emits coding-standard
  -- style sniffs (comma spacing, etc.) that are pure noise here; real
  -- cross-class diagnostics come from phpactor below.
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters_by_ft = {
        php = {},
      },
    },
  },
  -- phpactor is the PHP LSP (LazyVim default). Keep its cross-class
  -- diagnostics for correctness/theming, but silence the noise:
  --   * undefined-variable warnings fire on include-style files where
  --     `$this` legitimately comes from the including class's scope. The
  --     worse-reflection diagnostic is emitted with code
  --     `worse.undefined_variable`, so ignore that code.
  --   * don't surface phpcs / php-cs-fixer diagnostics via the LSP either,
  --     so phpcs stays fully off across both nvim-lint and phpactor.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        phpactor = {
          init_options = {
            ["language_server.diagnostic_ignore_codes"] = { "worse.undefined_variable" },
            ["php_code_sniffer.show_diagnostics"] = false,
            ["language_server_php_cs_fixer.show_diagnostics"] = false,
          },
        },
      },
    },
  },
}
