{
  modulesPath,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
  ];

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

  services.openssh.enable = true;

  security.sudo.wheelNeedsPassword = false;

  boot = {
    growPartition = true;
    kernelParams = [ "console=tty0" ];
    loader = {
      # VM images have no persistent EFI variable store; systemd-boot must
      # install to the removable fallback path (BOOTAA64.EFI / BOOTX64.EFI)
      efi.canTouchEfiVariables = false;
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
      autoResize = true;
      options = [
        "discard"
        "noatime"
        "nodiratime"
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    nix-output-monitor
  ];

  programs.direnv = {
    enable = true;
    silent = true;
  };

  virtualisation.rosetta = lib.mkIf pkgs.stdenv.hostPlatform.isAarch64 {
    enable = true;
    mountTag = "vz-rosetta";
  };

  system.activationScripts.removeChannels = "rm -rf /root/.nix-defexpr/channels /nix/var/nix/profiles/per-user/root/channels";

  system.stateVersion = "26.05";
}
