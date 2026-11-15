return {
  -- Resaltado de sintaxis (requiere el CLI `tree-sitter`)
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local langs = { "lua", "typescript", "tsx", "javascript", "json", "html", "css",
        "markdown", "markdown_inline", "bash", "rust", "toml", "yaml" }
      if vim.fn.executable("tree-sitter") == 1 then
        require("nvim-treesitter").install(langs)
      end
      vim.api.nvim_create_autocmd("FileType", {
        callback = function() pcall(vim.treesitter.start) end,
      })
    end,
  },

  -- Instalador de servidores de lenguaje (LSP)
  { "mason-org/mason.nvim", opts = {} },
  {
    "mason-org/mason-lspconfig.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig" },
    opts = {
      ensure_installed = { "lua_ls", "ts_ls", "eslint", "tailwindcss", "cssls", "html", "jsonls" },
      automatic_enable = true,
    },
    config = function(_, opts)
      vim.lsp.config("lua_ls", {
        settings = { Lua = { diagnostics = { globals = { "vim", "Snacks" } } } },
      })
      require("mason-lspconfig").setup(opts)

      vim.diagnostic.config({ virtual_text = true, severity_sort = true })
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local m = function(k, f, d) vim.keymap.set("n", k, f, { buffer = ev.buf, desc = d }) end
          m("gd", function() Snacks.picker.lsp_definitions() end, "Ir a definición")
          m("gr", function() Snacks.picker.lsp_references() end, "Referencias")
          m("K", vim.lsp.buf.hover, "Documentación")
          m("<leader>rn", vim.lsp.buf.rename, "Renombrar")
          m("<leader>ca", vim.lsp.buf.code_action, "Acciones de código")
          m("<leader>cf", function() vim.lsp.buf.format() end, "Formatear")
        end,
      })
    end,
  },

  -- Autocompletado
  {
    "saghen/blink.cmp",
    version = "1.*",
    event = "InsertEnter",
    opts = {
      keymap = { preset = "enter" }, -- Enter acepta, Tab/flechas navegan
      completion = { documentation = { auto_show = true } },
      signature = { enabled = true },
    },
  },
}
