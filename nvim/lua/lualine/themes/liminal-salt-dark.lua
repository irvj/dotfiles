-- Liminal Salt Dark — lualine theme
-- Colors from canonical theme: github.com/irvj/liminal-salt

local p = {
  stone50  = "#2e312f",
  stone100 = "#242726",
  stone200 = "#1a1c1b",
  beige300 = "#e8e4dc",
  beige600 = "#9e9b93",
  sage400  = "#8fac98",
  teal400  = "#95bebe",
  teal500  = "#8fb8ad",
  amber400 = "#c9a86c",
  red400   = "#cc8585",
}

return {
  normal = {
    a = { bg = p.sage400, fg = p.stone200, gui = "bold" },
    b = { bg = p.stone50, fg = p.beige300 },
    c = { bg = p.stone100, fg = p.beige600 },
  },
  insert = {
    a = { bg = p.teal400, fg = p.stone200, gui = "bold" },
    b = { bg = p.stone50, fg = p.beige300 },
    c = { bg = p.stone100, fg = p.beige600 },
  },
  visual = {
    a = { bg = p.amber400, fg = p.stone200, gui = "bold" },
    b = { bg = p.stone50, fg = p.beige300 },
    c = { bg = p.stone100, fg = p.beige600 },
  },
  replace = {
    a = { bg = p.red400, fg = p.stone200, gui = "bold" },
    b = { bg = p.stone50, fg = p.beige300 },
    c = { bg = p.stone100, fg = p.beige600 },
  },
  command = {
    a = { bg = p.teal500, fg = p.stone200, gui = "bold" },
    b = { bg = p.stone50, fg = p.beige300 },
    c = { bg = p.stone100, fg = p.beige600 },
  },
  terminal = {
    a = { bg = p.teal500, fg = p.stone200, gui = "bold" },
    b = { bg = p.stone50, fg = p.beige300 },
    c = { bg = p.stone100, fg = p.beige600 },
  },
  inactive = {
    a = { bg = p.stone100, fg = p.beige600 },
    b = { bg = p.stone100, fg = p.beige600 },
    c = { bg = p.stone100, fg = p.beige600 },
  },
}
