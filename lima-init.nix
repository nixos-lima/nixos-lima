{
  config,
  modulesPath,
  pkgs,
  lib,
  ...
}:

let
  LIMA_CIDATA_MNT = "/mnt/lima-cidata";
  LIMA_CIDATA_DEV = "/dev/disk/by-label/cidata";

  cfg = config.services.lima;

  script =
    lib.replaceStrings
      [ "@limaCidataMnt@" "@binPath@" ]
      [
        LIMA_CIDATA_MNT
        (pkgs.lib.makeBinPath [
          pkgs.shadow
          pkgs.gawk
          pkgs.mount
        ])
      ]
      (builtins.readFile ./lima-init.sh);
in
{
  imports = [ ];

  options = {
    services.lima = {
      enable = lib.mkEnableOption "lima-init, lima-guestagent, other Lima support";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.lima-init = {
      inherit script;
      description = "Reconfigure the system from lima-init userdata on startup";

      after = [ "network-pre.target" ];

      restartIfChanged = true;
      unitConfig.X-StopOnRemoval = false;

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    systemd.services.lima-guestagent = {
      enable = true;
      description = "Forward ports to the lima-hostagent";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "lima-init.service"
      ];
      requires = [ "lima-init.service" ];
      script = ''
        # We can't just source lima.env because values might have spaces in them
        while read -r line; do export "$line"; done < "${LIMA_CIDATA_MNT}"/lima.env
        ${LIMA_CIDATA_MNT}/lima-guestagent daemon --vsock-port "$LIMA_CIDATA_VSOCK_PORT"
      '';
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
      };
    };

    fileSystems."${LIMA_CIDATA_MNT}" = {
      device = "${LIMA_CIDATA_DEV}";
      fsType = "auto";
      options = [
        "ro"
        "mode=0700"
        "dmode=0700"
        "overriderockperm"
        "exec"
        "uid=0"
      ];
    };

    environment.etc = {
      environment.source = "${LIMA_CIDATA_MNT}/etc_environment";
    };

    networking.nat.enable = true;

    environment.systemPackages = with pkgs; [
      bash
      sshfs
      fuse3
      git
    ];

    boot.kernel.sysctl = {
      "kernel.unprivileged_userns_clone" = 1;
      "net.ipv4.ping_group_range" = "0 2147483647";
      "net.ipv4.ip_unprivileged_port_start" = 0;
    };
  };
}
