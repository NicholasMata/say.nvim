# sayit.nvim

Speak the word under the cursor or the current visual selection using macOS Text-to-Speech. 
Press the same key again to stop (toggle). 
Works on both Neovim 0.9+ and 0.10+.

## Features

- **Normal mode**: Speak the word under the cursor (e.g., `say <cword>`)
- **Visual mode**: Speak the selected text (supports character-, line-, and block-wise)
- Press the same key again to **stop** speaking
- Uses macOS `say` (preferred) or falls back to `osascript` if needed
- Integrates with both `vim.system()` (Neovim 0.10+) and `jobstart()` (0.9+)
- Minimal implementation, ~200 lines of code, easy to customize

## Requirements
- Neovim 0.9+
- macOS

## Installation

### With `lazy.nvim`:

```lua
{
  "nicholasmata/sayit.nvim",
  opts = {}
}
```

## Configuration

The example below shows all the possible configurations (with there defaults):
```lua
{
  mappings = {
    normal = "<leader>v", -- keybinding when in normal mode
    visual = "<leader>v", -- keybinding when in visual mode
	stop = false,         -- or a keybinding, e.g. "<leader>V"
  },
  exit_visual = true,     -- exit visual mode after speaking (default `true`)
}
```


