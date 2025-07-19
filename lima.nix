{ config, modulesPath, pkgs, lib, ... }:
{
    imports = [
        (modulesPath + "/profiles/qemu-guest.nix")
        ./lima-init.nix
    ];

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    services.lima.enable = true;

    # ssh
    services.openssh.enable = true;
    services.openssh.settings.PermitRootLogin = "yes";
    users.users.root.password = "nixos";

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

    system.stateVersion = "25.05";
}

