{ config, modulesPath, pkgs, lib, ... }:
{
    imports = [
        (modulesPath + "/profiles/qemu-guest.nix")
        ./lima-init.nix
    ];

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    # Give users in the `wheel` group additional rights when connecting to the Nix daemon
    # This simplifies remote deployment to the instance's nix store.
    nix.settings.trusted-users = [ "@wheel" ];

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
        device = lib.mkForce "/dev/vda1";  # /dev/disk/by-label/ESP
        fsType = "vfat";
    };
    fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        autoResize = true;
        fsType = "ext4";
        options = [ "noatime" "nodiratime" "discard" ];
    };

    # misc
    boot.kernelPackages = pkgs.linuxPackages_latest;

    # pkgs
    environment.systemPackages = with pkgs; [
        vim
        git
    ];

    system.stateVersion = "25.11";
}

