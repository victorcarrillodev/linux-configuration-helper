-- Ajustes sobre LazyVim para que se vea como en la captura
return {
  -- Tema oscuro estilo VS Code
  { "Mofiqul/vscode.nvim", opts = { style = "dark" } },
  { "LazyVim/LazyVim", opts = { colorscheme = "vscode" } },

  -- Pantalla de inicio: encabezado NEOVIM y menú f/n/g/r/p/q
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          header = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝]],
          keys = {
            { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
            { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
            { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = "󰒲 ", key = "p", desc = "Plugins", action = ":Lazy" },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
        },
      },
    },
  },

  -- Árbol lateral con pestañas File / Buffers / Git; se abre solo al iniciar sin archivos
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      source_selector = { winbar = true },
      filesystem = { filtered_items = { visible = true, hide_dotfiles = false } },
    },
    init = function()
      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
          if vim.fn.argc() == 0 then
            vim.schedule(function() vim.cmd("Neotree show") end)
          end
        end,
      })
    end,
  },
}
