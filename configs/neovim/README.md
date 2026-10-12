# Installation

### Unix

1. `git clone https://github.com/BSteffaniak/nvim.git ~/.config/nvim`
1. `~/.config/nvim/install.sh`

### Windows

1. `git clone https://github.com/BSteffaniak/nvim.git ~/.config/nvim`
1. `sh ~/.config/nvim/install.sh`

You'll need to install `~/.local/neovim-install` manually through 'Developer
Command Prompt for VS 2022' or similar:

```
cmake -S cmake.deps -B .deps -G Ninja -D CMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build .deps
cmake -B build -G Ninja -D CMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build
```

# Updating

1. `~/.config/nvim/install.sh update`
