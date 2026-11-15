return {
  -- Tema oscuro estilo VS Code
  {
    "Mofiqul/vscode.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("vscode").setup({ style = "dark" })
      vim.cmd.colorscheme("vscode")
    end,
  },

  -- Dashboard, buscador de archivos/texto, notificaciones
  {
    "folke/snacks.nvim",
    lazy = false,
    priority = 900,
    opts = {
      picker = { enabled = true },
      notifier = { enabled = true },
      indent = { enabled = true },
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
            { key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
            { key = "n", desc = "New File", action = ":ene | startinsert" },
            { key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
            { key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { key = "p", desc = "Plugins", action = ":Lazy" },
            { key = "q", desc = "Quit", action = ":qa" },
          },
        },
        sections = {
          { section = "header" },
          { section = "keys", gap = 1, padding = 1 },
          { section = "startup" },
        },
      },
    },
    keys = {
      { "<leader><space>", function() Snacks.picker.files() end, desc = "Buscar archivo" },
      { "<C-p>", function() Snacks.picker.files() end, desc = "Buscar archivo" },
      { "<leader>/", function() Snacks.picker.grep() end, desc = "Buscar texto" },
      { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recientes" },
      { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Pestañas abiertas" },
      { "<leader>gg", function() Snacks.lazygit() end, desc = "Lazygit" },
      { "<C-\\>", function() Snacks.terminal() end, mode = { "n", "t" }, desc = "Terminal" },
    },
  },

  -- Árbol de archivos lateral con pestañas File / Buffers / Git
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    keys = {
      { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "Explorador" },
    },
    opts = {
      close_if_last_window = true,
      source_selector = { winbar = true },
      window = { width = 32 },
      filesystem = {
        follow_current_file = { enabled = true },
        use_libuv_file_watcher = true,
        filtered_items = { visible = true, hide_dotfiles = false },
      },
    },
    init = function()
      -- Al abrir nvim sin archivos: dashboard + árbol a la izquierda
      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
          if vim.fn.argc() == 0 then
            vim.schedule(function() vim.cmd("Neotree show") end)
          end
        end,
      })
    end,
  },

  -- Barra de estado inferior
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      options = { theme = "vscode", globalstatus = true },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "diagnostics", "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },

  -- Pestañas arriba
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        offsets = { { filetype = "neo-tree", text = "Explorador", separator = true } },
        diagnostics = "nvim_lsp",
      },
    },
  },

  -- Cambios de git en el margen
  { "lewis6991/gitsigns.nvim", event = "BufReadPre", opts = {} },

  -- Muestra los atajos al pulsar Espacio
  { "folke/which-key.nvim", event = "VeryLazy", opts = {} },

  -- Autocierre de paréntesis y comillas
  { "windwp/nvim-autopairs", event = "InsertEnter", opts = {} },
}
