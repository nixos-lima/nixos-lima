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

  # Get image under 2GB for Github release.
  documentation.enable = false;

  # Give users in the `wheel` group additional rights when connecting to the Nix daemon
  # This simplifies remote deployment to the instance's nix store.
  nix = {
    channel.enable = false;

    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "flakes"
        "nix-command"
      ];
      min-free = "8G";
      max-free = "32G";
      trusted-users = [ "@wheel" ];
    };
  };

  # Read Lima configuration at boot time and run the Lima guest agent
  services.lima.enable = true;

  # ssh
  services.openssh.enable = true;

  security = {
    sudo = {
      enable = true;
      wheelNeedsPassword = false;
    };
  };

  # system mounts
  boot = {
    kernelParams = [ "console=tty0" ];
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
  };
  fileSystems = {
    "/boot" = {
      device = lib.mkForce "/dev/vda1";
      fsType = "vfat";
      options = [
        "discard"
        "noatime"
        "umask=0077"
      ];
    };
    "/" = {
      device = lib.mkForce "/dev/vda2";
      fsType = "ext4";
      options = [
        "discard"
        "noatime"
        "nodiratime"
      ];
    };
  };

  # pkgs
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    direnv
    nix-output-monitor
  ];

  programs = {
    direnv = {
      enable = true;
      silent = true;
    };
  };

  system.stateVersion = "25.11";

  virtualisation.rosetta = {
    enable = pkgs.stdenv.hostPlatform.isAarch64;
    mountTag = "vz-rosetta";
  };
}
