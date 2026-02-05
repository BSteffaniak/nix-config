-- Hammerspoon configuration
-- Replaces Karabiner-Elements to avoid virtual HID keyboard breaking
-- Dvorak Ctrl key mappings

-- Disable animations for instant feedback
hs.window.animationDuration = 0

-- Application preferences
hs.autoLaunch(true)                    -- Start at login
hs.automaticallyCheckForUpdates(false) -- Managed by homebrew
hs.uploadCrashData(false)              -- No crash reports
hs.menuIcon(false)                     -- Hide menu bar icon
hs.dockIcon(false)                     -- Hide dock icon
hs.openConsoleOnDockClick(false)       -- Don't open console on dock click

--------------------------------------------------------------------------------
-- Input source switching
--------------------------------------------------------------------------------

hs.hotkey.bind({ "cmd", "alt" }, "1", function()
  hs.keycodes.currentSourceID("com.apple.keylayout.US")
end)

hs.hotkey.bind({ "cmd", "alt" }, "2", function()
  hs.keycodes.currentSourceID("com.apple.keylayout.Dvorak")
end)

--------------------------------------------------------------------------------
-- Ctrl+; -> Ctrl+s in terminal apps (for Zellij/tmux navigation)
-- Uses hs.hotkey + app watcher instead of hs.eventtap for resilience
-- (hs.eventtap can silently die during nix rebuilds; hs.hotkey survives)
--------------------------------------------------------------------------------

local terminalBundleIDs = {
  ["com.mitchellh.ghostty"] = true,
  ["net.kovidgoyal.kitty"] = true,
  ["com.github.wez.wezterm"] = true,
  ["com.googlecode.iterm2"] = true,
  ["com.apple.Terminal"] = true,
}

-- Create hotkey (disabled by default) - enabled only when a terminal is focused
local ctrlSemicolonHotkey = hs.hotkey.new({ "ctrl" }, ";", function()
  hs.eventtap.keyStroke({ "ctrl" }, "s", 0)
end)

-- Watch for application focus changes to enable/disable the hotkey
local appWatcher = hs.application.watcher.new(function(appName, eventType, appObject)
  if eventType == hs.application.watcher.activated then
    if appObject and terminalBundleIDs[appObject:bundleID()] then
      ctrlSemicolonHotkey:enable()
    else
      ctrlSemicolonHotkey:disable()
    end
  end
end)
appWatcher:start()

-- Enable hotkey if a terminal is already focused at load time
local frontApp = hs.application.frontmostApplication()
if frontApp and terminalBundleIDs[frontApp:bundleID()] then
  ctrlSemicolonHotkey:enable()
end

--------------------------------------------------------------------------------
-- Auto-reload config when init.lua changes (e.g. after nix rebuild)
--------------------------------------------------------------------------------

local configWatcher = hs.pathwatcher.new(hs.configdir, function(files)
  for _, file in pairs(files) do
    if file:sub(-#"init.lua") == "init.lua" then
      hs.reload()
      return
    end
  end
end)
configWatcher:start()

--------------------------------------------------------------------------------
-- Reload config notification
--------------------------------------------------------------------------------

hs.alert.show("Hammerspoon config loaded")
