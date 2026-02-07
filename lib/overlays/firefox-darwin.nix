# Auto-discovered overlay for Firefox on darwin
# Enable with: enableFirefoxDarwin = true
{
  inputs,
  enable ? true,
  mkGitInput ? null,
}:
if !enable then
  [ ]
else
  let
    firefox-darwin = inputs.firefox-darwin or null;
  in
  if firefox-darwin == null then
    [ ]
  else
    [
      firefox-darwin.overlay
    ]
