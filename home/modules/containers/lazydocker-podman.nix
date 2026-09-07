{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myConfig.containers.tools;
  # Private compatibility commands: never replace Docker globally.
  podmanDocker = pkgs.writeShellScriptBin "docker" ''
    if [ "''${1:-}" = compose ]; then
      shift
      exec ${pkgs.podman-compose}/bin/podman-compose "$@"
    fi
    exec ${pkgs.podman}/bin/podman "$@"
  '';
  podmanDockerCompose = pkgs.writeShellScriptBin "docker-compose" ''
    exec ${pkgs.podman-compose}/bin/podman-compose "$@"
  '';
  lazydockerPodman = pkgs.writeShellApplication {
    name = "lazydocker-podman";
    runtimeInputs = [
      pkgs.podman
      pkgs.jq
      pkgs.fzf
      pkgs.curl
    ];
    text = ''
      if [[ "''${1:-}" == --help || "''${1:-}" == -h ]]; then
        echo 'Usage: lazydocker-podman [MACHINE]'
        echo 'Choose a Podman machine and open lazydocker. Prompts before starting stopped machines.'
        exit 0
      fi
      if (( $# > 1 )); then
        echo 'Usage: lazydocker-podman [MACHINE]' >&2
        exit 2
      fi

      machines=$(podman machine list --format json)
      if [[ $(jq 'length' <<< "$machines") == 0 ]]; then
        echo 'No Podman machines found. Create one with podman machine init.' >&2
        exit 1
      fi
      machine="''${1:-}"
      if [[ -z "$machine" ]]; then
        rows=$(jq -r '.[] | [.Name, (if .Running then "running" elif .Starting then "starting" else "stopped" end)] | @tsv' <<< "$machines")
        selection=$(printf '%s\n' "$rows" | fzf --prompt='Podman machine> ' --header='Select a machine for lazydocker') || exit 0
        machine="''${selection%%$'\t'*}"
      fi
      entry=$(jq -ce --arg name "$machine" '.[] | select(.Name == $name)' <<< "$machines") || {
        echo "Unknown Podman machine: $machine" >&2
        exit 1
      }
      if [[ $(jq -r '.Starting' <<< "$entry") == true ]]; then
        echo "$machine is already starting. Wait for startup to finish and retry." >&2
        exit 1
      fi
      if [[ $(jq -r '.Running' <<< "$entry") != true ]]; then
        read -r -p "Start Podman machine $machine? [y/N] " answer
        case "$answer" in
          y|Y|yes|YES) podman machine start "$machine" ;;
          *) exit 0 ;;
        esac
      fi

      info=$(podman machine inspect "$machine")
      socket=$(jq -er '.[0].ConnectionInfo.PodmanSocket.Path | select(length > 0)' <<< "$info")
      # Keep CLI commands on the same rootful/rootless engine as the API socket.
      export CONTAINER_HOST
      connections=$(podman system connection list --format json)
      connection="$machine"
      if [[ $(jq -r '.[0].Rootful' <<< "$info") == true ]]; then
        connection="$machine-root"
      fi
      CONTAINER_HOST=$(jq -er --arg name "$connection" '.[] | select(.Name == $name) | .URI' <<< "$connections")
      export CONTAINER_SSHKEY
      CONTAINER_SSHKEY=$(jq -er '.[0].SSHConfig.IdentityPath' <<< "$info")
      unset CONTAINER_CONNECTION DOCKER_CONTEXT DOCKER_TLS_VERIFY DOCKER_CERT_PATH
      export DOCKER_HOST="unix://$socket"
      if ! curl --silent --show-error --fail --max-time 5 --unix-socket "$socket" http://localhost/_ping > /dev/null; then
        echo "Podman API socket is unavailable for $machine: $socket" >&2
        exit 1
      fi
      podman info > /dev/null
      export PATH="${podmanDocker}/bin:${podmanDockerCompose}/bin:$PATH"
      echo "Opening lazydocker on $machine"
      exec ${pkgs.lazydocker}/bin/lazydocker
    '';
  };
in
{
  config =
    lib.mkIf
      (
        cfg.enable
        && cfg.includeLazydocker
        && config.myConfig.containers.podman.enable
        && pkgs.stdenv.isDarwin
      )
      {
        home.packages = [ lazydockerPodman ];
      };
}
