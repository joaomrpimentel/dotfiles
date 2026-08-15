-- Monochrome colorscheme: zenwritten (zenbones family).
-- Grayscale UI with just enough contrast for treesitter/LSP, and a
-- transparent background so kitty's translucency shows through.
return {
  { "rktjmp/lush.nvim", lazy = true },
  {
    "mcchrish/zenbones.nvim",
    dependencies = { "rktjmp/lush.nvim" },
    priority = 1000,
    config = function()
      vim.g.zenbones_darken_comments = 45
      vim.g.zenwritten_transparent_background = true
      vim.g.zenwritten_lighten_noncurrent_window = true
      vim.o.background = "dark"
      vim.cmd("colorscheme zenwritten")

      -- Keep floats/splits reading as one surface with the terminal
      for _, group in ipairs({ "NormalFloat", "FloatBorder", "SignColumn", "NormalNC" }) do
        vim.api.nvim_set_hl(0, group, { bg = "none" })
      end
      vim.api.nvim_set_hl(0, "WinSeparator", { fg = "#2a2a2a", bg = "none" })
    end,
  },
}
