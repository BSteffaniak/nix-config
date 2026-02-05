{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.desktop.karabiner;

  # Terminal bundle identifiers for Ctrl+; -> Ctrl+s mapping
  terminalBundleIds = [
    "^com\\.mitchellh\\.ghostty$"
    "^net\\.kovidgoyal\\.kitty$"
    "^com\\.github\\.wez\\.wezterm$"
    "^com\\.googlecode\\.iterm2$"
    "^com\\.apple\\.Terminal$"
  ];

  # Karabiner configuration
  karabinerConfig = {
    global = {
      check_for_updates_on_startup = true;
      show_in_menu_bar = true;
      show_profile_name_in_menu_bar = false;
      unsafe_ui = false;
    };
    profiles = [
      {
        name = "Default profile";
        selected = true;
        virtual_hid_keyboard = {
          keyboard_type_v2 = "ansi";
        };
        complex_modifications = {
          parameters = {
            "basic.simultaneous_threshold_milliseconds" = 50;
            "basic.to_delayed_action_delay_milliseconds" = 500;
            "basic.to_if_alone_timeout_milliseconds" = 1000;
            "basic.to_if_held_down_threshold_milliseconds" = 500;
          };
          rules = [
            # Rule 1: Ctrl+; -> Ctrl+s in terminals
            {
              description = "Ctrl+; -> Ctrl+s in terminals (for Zellij/tmux navigation)";
              manipulators = [
                {
                  type = "basic";
                  from = {
                    key_code = "semicolon";
                    modifiers = {
                      mandatory = [ "control" ];
                      optional = [ "any" ];
                    };
                  };
                  to = [
                    {
                      key_code = "s";
                      modifiers = [ "control" ];
                    }
                  ];
                  conditions = [
                    {
                      type = "frontmost_application_if";
                      bundle_identifiers = terminalBundleIds;
                    }
                  ];
                }
              ];
            }
            # Rule 2: Cmd+Alt+1 -> Switch to Default profile
            {
              description = "Cmd+Alt+1 -> Switch to Default profile";
              manipulators = [
                {
                  type = "basic";
                  from = {
                    key_code = "1";
                    modifiers = {
                      mandatory = [
                        "command"
                        "option"
                      ];
                    };
                  };
                  to = [
                    {
                      shell_command = "'/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli' --select-profile 'Default profile'";
                    }
                  ];
                }
              ];
            }
            # Rule 3: Cmd+Alt+2 -> Switch to Dvorak profile
            {
              description = "Cmd+Alt+2 -> Switch to Dvorak profile";
              manipulators = [
                {
                  type = "basic";
                  from = {
                    key_code = "2";
                    modifiers = {
                      mandatory = [
                        "command"
                        "option"
                      ];
                    };
                  };
                  to = [
                    {
                      shell_command = "'/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli' --select-profile 'Dvorak'";
                    }
                  ];
                }
              ];
            }
          ];
        };
        # Empty simple/fn/device modifications (can be extended later)
        simple_modifications = [ ];
        fn_function_keys = [ ];
        devices = [ ];
      }
      # Dvorak profile (minimal - just a placeholder for switching)
      {
        name = "Dvorak";
        selected = false;
        virtual_hid_keyboard = {
          keyboard_type_v2 = "ansi";
        };
        complex_modifications = {
          parameters = {
            "basic.simultaneous_threshold_milliseconds" = 50;
            "basic.to_delayed_action_delay_milliseconds" = 500;
            "basic.to_if_alone_timeout_milliseconds" = 1000;
            "basic.to_if_held_down_threshold_milliseconds" = 500;
          };
          rules = [
            # Profile switching rules
            {
              description = "Cmd+Alt+1 -> Switch to Default profile";
              manipulators = [
                {
                  type = "basic";
                  from = {
                    key_code = "1";
                    modifiers = {
                      mandatory = [
                        "command"
                        "option"
                      ];
                    };
                  };
                  to = [
                    {
                      shell_command = "'/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli' --select-profile 'Default profile'";
                    }
                  ];
                }
              ];
            }
            {
              description = "Cmd+Alt+2 -> Switch to Dvorak profile";
              manipulators = [
                {
                  type = "basic";
                  from = {
                    key_code = "2";
                    modifiers = {
                      mandatory = [
                        "command"
                        "option"
                      ];
                    };
                  };
                  to = [
                    {
                      shell_command = "'/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli' --select-profile 'Dvorak'";
                    }
                  ];
                }
              ];
            }
          ];
        };
        simple_modifications = [ ];
        fn_function_keys = [ ];
        devices = [ ];
      }
    ];
  };
in
{
  options.myConfig.desktop.karabiner = {
    enable = mkEnableOption "Karabiner-Elements keyboard customization";
  };

  config = mkIf cfg.enable {
    xdg.configFile."karabiner/karabiner.json" = {
      text = builtins.toJSON karabinerConfig;
    };
  };
}
