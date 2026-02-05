-- Hammerspoon configuration
-- Replaces Karabiner-Elements to avoid virtual HID keyboard breaking
-- Dvorak Ctrl key mappings

-- Disable animations for instant feedback
hs.window.animationDuration = 0

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
--------------------------------------------------------------------------------

local terminalBundleIDs = {
  ["com.mitchellh.ghostty"] = true,
  ["net.kovidgoyal.kitty"] = true,
  ["com.github.wez.wezterm"] = true,
  ["com.googlecode.iterm2"] = true,
  ["com.apple.Terminal"] = true,
}

local ctrlSemicolonWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
  local flags = event:getFlags()
  local keycode = event:getKeyCode()

  -- Dynamically resolve semicolon keycode based on current input source
  -- This ensures it works correctly on both QWERTY and Dvorak layouts
  local semicolonKeycode = hs.keycodes.map[";"]
  if flags.ctrl and semicolonKeycode and keycode == semicolonKeycode then
    local app = hs.application.frontmostApplication()
    if app and terminalBundleIDs[app:bundleID()] then
      hs.eventtap.keyStroke({ "ctrl" }, "s", 0)
      return true -- consume original event
    end
  end

  return false
end)
ctrlSemicolonWatcher:start()

--------------------------------------------------------------------------------
-- Reload config notification
--------------------------------------------------------------------------------

hs.alert.show("Hammerspoon config loaded")
