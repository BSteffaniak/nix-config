{
  imports = [
    # Import the original home/modules files (fish, git, gtk-theming)
    ./fish.nix
    ./git.nix
    ./gtk-theming.nix

    # Import new module categories
    ./development
    ./containers
    ./devops
    ./shell
    ./editors
    ./cli-tools
    ./desktop
    ./tools
  ];
}
