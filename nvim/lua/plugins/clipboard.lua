-- Ergonomic "yank to system clipboard" keys.
--
-- Over SSH, LazyVim intentionally leaves 'clipboard' empty so normal y/p stay
-- fast and never hang on a terminal clipboard query. To copy OUT to the local
-- machine you use the '+' register, which Neovim sends via OSC 52 (tmux
-- forwards it -- see `set-clipboard on` in tmux.conf). Typing `"+y` by hand is
-- awful, so map it to <leader>y (Space-y):
--
--   <leader>y   normal/visual : yank motion/selection to system clipboard
--   <leader>Y   normal        : yank the current line to system clipboard
--
-- Normal y/p are untouched (still fast, in-editor). Paste local -> remote is
-- terminal paste (Ctrl+Shift+V); OSC 52 can't read the clipboard back.
return {
  {
    "LazyVim/LazyVim",
    keys = {
      { "<leader>y", '"+y', mode = { "n", "x" }, desc = "Yank to system clipboard" },
      { "<leader>Y", '"+Y', mode = "n", desc = "Yank line to system clipboard" },
    },
  },
}
