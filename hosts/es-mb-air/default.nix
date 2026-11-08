{
  imports = [
    ../../modules/common
    ../../modules/darwin
  ];

  myConfig = {
    shell.default = "zsh";
    services.sshd.enable = true;
  };
}
