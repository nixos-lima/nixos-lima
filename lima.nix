{
  config,
  modulesPath,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./lima-init.nix
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Give users in the `wheel` group additional rights when connecting to the Nix daemon
  # This simplifies remote deployment to the instance's nix store.
  nix.settings.trusted-users = [ "@wheel" ];

  # lima-init imperatively adds a user at startup. `users.mutableUsers` should be `true`
  # to prevent `nixos-rebuild` from overwriting that user which can cause login to fail.
  # The default is `true`, but we'll set it explicitly to document our requirement.
  users.mutableUsers = true;

  # Read Lima configuration at boot time and run the Lima guest agent
  services.lima.enable = true;

  # ssh
  services.openssh.enable = true;

  security = {
    sudo.wheelNeedsPassword = false;
  };

  # system mounts
  boot = {
    kernelParams = [ "console=tty0" ];
    loader.grub = {
      device = "nodev";
      efiSupport = true;
      efiInstallAsRemovable = true;
    };
  };
  fileSystems."/boot" = {
    device = lib.mkForce "/dev/vda1"; # /dev/disk/by-label/ESP
    fsType = "vfat";
  };
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    autoResize = true;
    fsType = "ext4";
    options = [
      "noatime"
      "nodiratime"
      "discard"
    ];
  };

  # misc
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # pkgs
  environment.systemPackages = with pkgs; [
    nextvi # small version of vi
    gitMinimal # minimal version of git
  ];

  system.stateVersion = "25.11";
}
