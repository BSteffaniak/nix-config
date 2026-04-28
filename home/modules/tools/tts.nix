# Text-to-speech tools installed via home-manager.
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.myConfig.tools.tts;

  packagedVoices = {
    en_US-lessac-medium = {
      model = pkgs.fetchurl {
        url = "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx";
        sha256 = "17q1mzm6xd5i2rxx2xwqkxvfx796kmp1lvk4mwkph602k7k0kzjy";
      };
      config = pkgs.fetchurl {
        url = "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json";
        sha256 = "184hnvd8389xpdm0x2w6phss23v5pb34i0lhd4nmy1gdgd0rrqgg";
      };
    };
  };

  usingPackagedVoice = cfg.piper.modelPath == null;
  voice = packagedVoices.${cfg.piper.defaultVoice};
  voiceDir = ".local/share/tts/piper/voices";
  voiceModelPath =
    if cfg.piper.modelPath != null then
      cfg.piper.modelPath
    else
      "${config.home.homeDirectory}/${voiceDir}/${cfg.piper.defaultVoice}.onnx";
  voiceConfigPath =
    if cfg.piper.configPath != null then
      cfg.piper.configPath
    else if cfg.piper.modelPath != null then
      "${cfg.piper.modelPath}.json"
    else
      "${config.home.homeDirectory}/${voiceDir}/${cfg.piper.defaultVoice}.onnx.json";

  ttsSay = pkgs.writeShellScriptBin "tts-say" ''
    set -euo pipefail

    model="''${PIPER_VOICE:-${voiceModelPath}}"
    config="''${PIPER_VOICE_CONFIG:-${voiceConfigPath}}"

    if [ "$#" -gt 0 ]; then
      text="$*"
    else
      text="$(cat)"
    fi

    if [ -z "$text" ]; then
      exit 0
    fi

    tmp="''${TMPDIR:-/tmp}/tts-say.$$.$RANDOM.wav"
    cleanup() {
      rm -f "$tmp"
    }
    trap cleanup EXIT

    args=(--model "$model" --output_file "$tmp")
    if [ -n "$config" ] && [ -f "$config" ]; then
      args+=(--config "$config")
    fi
    if [ -n "''${PIPER_LENGTH_SCALE:-}" ]; then
      args+=(--length-scale "$PIPER_LENGTH_SCALE")
    fi
    if [ -n "''${PIPER_NOISE_SCALE:-}" ]; then
      args+=(--noise-scale "$PIPER_NOISE_SCALE")
    fi
    if [ -n "''${PIPER_NOISE_W_SCALE:-}" ]; then
      args+=(--noise-w-scale "$PIPER_NOISE_W_SCALE")
    fi
    if [ -n "''${PIPER_SENTENCE_SILENCE:-}" ]; then
      args+=(--sentence-silence "$PIPER_SENTENCE_SILENCE")
    fi
    if [ -n "''${PIPER_VOLUME:-}" ]; then
      args+=(--volume "$PIPER_VOLUME")
    fi

    printf '%s\n' "$text" | ${pkgs.piper-tts}/bin/piper "''${args[@]}"

    if [ -n "''${TTS_AUDIO_PLAYER:-}" ]; then
      "$TTS_AUDIO_PLAYER" "$tmp"
      exit 0
    fi

    if command -v afplay >/dev/null 2>&1; then
      afplay "$tmp"
    elif command -v aplay >/dev/null 2>&1; then
      aplay "$tmp"
    elif command -v paplay >/dev/null 2>&1; then
      paplay "$tmp"
    elif command -v ffplay >/dev/null 2>&1; then
      ffplay -nodisp -autoexit -loglevel quiet "$tmp"
    elif command -v mpv >/dev/null 2>&1; then
      mpv --really-quiet "$tmp"
    else
      echo "No audio player found. Install alsa-utils, pulseaudio, ffmpeg, or mpv; macOS uses afplay." >&2
      exit 1
    fi
  '';
in
{
  options.myConfig.tools.tts = {
    piper = {
      enable = mkEnableOption "Piper local/offline text-to-speech";

      defaultVoice = mkOption {
        type = types.enum (attrNames packagedVoices);
        default = "en_US-lessac-medium";
        description = "Packaged Piper voice to install when modelPath is not set.";
      };

      modelPath = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "$HOME/.local/share/tts/piper/voices/en_US-lessac-medium.onnx";
        description = "Optional external Piper ONNX model path. When null, the packaged defaultVoice is installed.";
      };

      configPath = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "$HOME/.local/share/tts/piper/voices/en_US-lessac-medium.onnx.json";
        description = "Optional external Piper voice config path. Defaults to modelPath + .json for external models.";
      };
    };
  };

  config = mkIf cfg.piper.enable (mkMerge [
    {
      home.packages = [
        pkgs.piper-tts
        ttsSay
      ]
      ++ optional pkgs.stdenv.isLinux pkgs.alsa-utils;

      home.sessionVariables = {
        TTS_BACKEND = "piper";
        PIPER_VOICE = voiceModelPath;
        PIPER_VOICE_CONFIG = voiceConfigPath;
      };
    }

    (mkIf usingPackagedVoice {
      home.file."${voiceDir}/${cfg.piper.defaultVoice}.onnx".source = voice.model;
      home.file."${voiceDir}/${cfg.piper.defaultVoice}.onnx.json".source = voice.config;
    })
  ]);
}
