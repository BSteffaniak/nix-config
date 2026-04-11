-- Load host-specific configuration with fallback to defaults
-- This allows the config to work both with Nix (which generates host-config.lua)
-- and standalone (where host-config.lua may not exist)
local ok, host_config = pcall(require, "host-config")
if not ok then
  -- Standalone mode - use sensible defaults
  -- Enable most plugins by default, except host-specific ones
  host_config = {
    plugins = {
      supermaven = true,    -- Enable AI assistant by default
      copilot = false,      -- Disabled (use supermaven instead)
      avante = false,       -- Disabled (heavy dependency chain)
      jdtls = true,         -- Enable Java tools
      elixir = true,        -- Enable Elixir support
      ionide = true,        -- Enable F# support
      dadbod = true,        -- Enable database tools
      treesitter_hypr = false, -- Disabled (Hyprland-specific, not universal)
    },
  }
end

-- Core plugins that are always enabled
local plugins = {
  "tweekmonster/startuptime.vim",

  "williamboman/mason.nvim",
  "williamboman/mason-lspconfig.nvim",
  "neovim/nvim-lspconfig",

  "lewis6991/gitsigns.nvim",

  "srcery-colors/srcery-vim",

  {
    "folke/trouble.nvim",
    wants = "nvim-web-devicons",
    cmd = { "TroubleToggle", "Trouble" },
    init = function()
      require("trouble").setup({
        use_diagnostic_signs = true,
      })
    end,
  },

  -- Visualize lsp progress
  {
    "j-hui/fidget.nvim",
    init = function()
      require("fidget").setup()
    end,
    tag = "legacy",
  },
  {
    "nvimtools/none-ls.nvim",
    dependencies = {
      "nvimtools/none-ls-extras.nvim",
      "gbprod/none-ls-shellcheck.nvim",
    },
  },

  "jay-babu/mason-null-ls.nvim",

  -- Autocompletion framework
  "hrsh7th/nvim-cmp",
  {
    -- cmp LSP completion
    "hrsh7th/cmp-nvim-lsp",
    -- cmp Snippet completion
    "hrsh7th/cmp-vsnip",
    -- cmp Path completion
    "hrsh7th/cmp-path",
    "hrsh7th/cmp-buffer",
    after = { "hrsh7th/nvim-cmp" },
    dependencies = { "hrsh7th/nvim-cmp" },
  },
  -- See hrsh7th other plugins for more great completion sources!
  -- Snippet engine
  "hrsh7th/vim-vsnip",

  {
    "mrcjkb/rustaceanvim",
    -- version = "^4", -- Recommended
  },

  -- Optional
  "nvim-telescope/telescope.nvim",
  "wincent/ferret",

  {
    "ibhagwan/fzf-lua",
    -- optional for icon support
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      -- calling `setup` is optional for customization
    end,
  },

  -- {
  --   "nvim-tree/nvim-tree.lua",
  --   dependencies = {
  --     "nvim-tree/nvim-web-devicons", -- optional, for file icons
  --   },
  -- },

  "airblade/vim-gitgutter",

  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").setup({})
    end,
  },

  {
    "creativenull/diagnosticls-configs-nvim",
    tag = "v0.1.8",
    dependencies = "neovim/nvim-lspconfig",
  },

  "f-person/git-blame.nvim",

  {
    "iamcco/markdown-preview.nvim",
    build = function()
      vim.fn["mkdp#util#install"]()
    end,
    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
    end,
    ft = { "markdown" },
  },

  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons", opt = true },
    init = function()
      require("lualine").setup({
        sections = {
          lualine_c = {
            {
              "filename",
              file_status = true, -- displays file status (readonly status, modified status)
              path = 1,    -- 0 = just filename, 1 = relative path, 2 = absolute path
            },
          },
        },
      })
    end,
  },

  "rrethy/vim-illuminate",

  "wesQ3/vim-windowswap",

  {
    "BSteffaniak/maximize.nvim",
    init = function()
      require("maximize").setup()
    end,
  },

  {
    "ray-x/lsp_signature.nvim",
  },

  "tpope/vim-fugitive",
  "tpope/vim-commentary",
  "tpope/vim-capslock",

  "wuelnerdotexe/vim-astro",

  "HerringtonDarkholme/yats.vim",

  {
    "fabridamicelli/cronex.nvim",
    opts = {},
    config = function()
      -- Initialize module (important to create namespace)
      require("cronex").setup({})
      -- Grab the namespace that Cronex uses for the explanations
      local ns = vim.api.nvim_get_namespaces()["cronex"]
      -- Override the config only for that namespace
      vim.diagnostic.config({
        virtual_text = {
          prefix = "󰥔",
        },
      }, ns)
    end,
  },

  {
    "stevearc/oil.nvim",
    opts = {},
    dependencies = { { "echasnovski/mini.icons", opts = {} } },
  },

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer Local Keymaps (which-key)",
      },
    },
  },

  "stevearc/dressing.nvim",
}

-- Conditional plugins based on host configuration

-- Elixir plugins
if host_config.plugins.elixir then
  table.insert(plugins, { "mhanberg/elixir.nvim", dependencies = { "nvim-lua/plenary.nvim" } })
  table.insert(plugins, "elixir-editors/vim-elixir")
end

-- Java development tools
if host_config.plugins.jdtls then
  table.insert(plugins, "mfussenegger/nvim-jdtls")
end

-- F# support (Ionide)
if host_config.plugins.ionide then
  table.insert(plugins, "ionide/Ionide-vim")
end

-- Database tools
if host_config.plugins.dadbod then
  table.insert(plugins, "tpope/vim-dadbod")
  table.insert(plugins, "kristijanhusak/vim-dadbod-ui")
end

-- Tree-sitter Hyprland support
if host_config.plugins.treesitter_hypr then
  -- Add the hypr dependency to nvim-treesitter
  for i, plugin in ipairs(plugins) do
    if type(plugin) == "table" and plugin[1] == "nvim-treesitter/nvim-treesitter" then
      if not plugin.dependencies then
        plugin.dependencies = {}
      end
      -- Check if dependencies is a table or string
      if type(plugin.dependencies) == "string" then
        plugin.dependencies = { plugin.dependencies }
      end
      table.insert(plugin.dependencies, { "luckasRanarison/tree-sitter-hypr" })

      -- Update the config to include hypr parser
      local original_config = plugin.config
      plugin.config = function()
        local parsers = require("nvim-treesitter.parsers")
        parsers.hypr = {
          install_info = {
            url = "https://github.com/luckasRanarison/tree-sitter-hypr",
            files = { "src/parser.c" },
            branch = "master",
          },
          filetype = "hypr",
        }

        if original_config then
          original_config()
        end
      end
      break
    end
  end
end

-- AI assistants (mutually exclusive recommended)
if host_config.plugins.supermaven then
  table.insert(plugins, {
    "supermaven-inc/supermaven-nvim",
    config = function()
      require("supermaven-nvim").setup({
        keymaps = {
          accept_suggestion = "<A-Tab>",
          clear_suggestion = "<A-Enter>",
        },
      })
    end,
  })
end

if host_config.plugins.copilot then
  table.insert(plugins, { "github/copilot.vim" })
end

if host_config.plugins.avante then
  table.insert(plugins, {
    "yetone/avante.nvim",
    event = "VeryLazy",
    version = false, -- Never set this value to "*"! Never!
    opts = {
      -- add any opts here
      -- for example
      provider = "openai",
      openai = {
        endpoint = "https://api.openai.com/v1",
        -- model = "gpt-4o", -- your desired model (or use gpt-4o, etc.)
        -- model = "o4-mini-high",
        model = "o3-mini",
        timeout = 30000,          -- Timeout in milliseconds, increase this for reasoning models
        temperature = 0,
        max_completion_tokens = 8192, -- Increase this to include reasoning tokens (for reasoning models)
        --reasoning_effort = "medium", -- low|medium|high, only used for reasoning models
      },
      mappings = {
        submit = {
          -- keep the default Normal‑mode submit on <CR>…
          normal = "<CR>",
          -- …but switch Insert‑mode submit to <C‑e> instead of <C‑s>
          insert = "<C-e>",
        },
      },
    },
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    build = "make",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      --- The below dependencies are optional,
      "echasnovski/mini.pick",      -- for file_selector provider mini.pick
      "nvim-telescope/telescope.nvim", -- for file_selector provider telescope
      "hrsh7th/nvim-cmp",           -- autocompletion for avante commands and mentions
      "ibhagwan/fzf-lua",           -- for file_selector provider fzf
      "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
      "zbirenbaum/copilot.lua",     -- for providers='copilot'
      {
        -- support for image pasting
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
          -- recommended settings
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
            -- required for Windows users
            -- use_absolute_path = true,
          },
        },
      },
      {
        -- Make sure to set this up properly if you have lazy=true
        "MeanderingProgrammer/render-markdown.nvim",
        opts = {
          file_types = { "markdown", "Avante" },
        },
        ft = { "markdown", "Avante" },
      },
    },
  })
end

-- Setup lazy.nvim with all plugins
require("lazy").setup(plugins)
