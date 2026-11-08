{
  myConfig.shell = {
    # Fleet enrollment is two-way; enroll this Mac's public keys after activation.
    ssh.enable = true;
    ssh.fleet.enable = true;
    shared.completions.useCarapace = false;
  };
}
