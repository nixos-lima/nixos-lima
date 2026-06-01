{
  config,
  pkgs,
  lib,
  ...
}:

let
  LIMA_CIDATA_MNT = "/mnt/lima-cidata";
  LIMA_CIDATA_DEV = "/dev/disk/by-label/cidata";

  cfg = config.services.lima;

  fstabAwk = pkgs.writeText "lima-fstab.awk" ''
    /^mounts:/ { flag=1; next }
    /^[^:]*:/ { flag=0 }
    /^ *$/ { flag=0 }
    flag {
      sub(/^ *- \[/, "")
      sub(/"?\] *$/, "")
      gsub("\"?, \"?", "\t")
      print $0
    }
  '';

  limaInit = pkgs.writeShellApplication {
    name = "lima-init";
    runtimeInputs = with pkgs; [
      shadow
      gawk
    ];
    text = ''
      LIMA_CIDATA_USER="''${LIMA_CIDATA_USER:?}"
      LIMA_CIDATA_HOME="''${LIMA_CIDATA_HOME:?}"
      LIMA_CIDATA_UID="''${LIMA_CIDATA_UID:?}"

      # Create user
      id -u "$LIMA_CIDATA_USER" >/dev/null 2>&1 || \
        useradd --home-dir "$LIMA_CIDATA_HOME" --create-home --uid "$LIMA_CIDATA_UID" "$LIMA_CIDATA_USER"

      usermod -a -G wheel "$LIMA_CIDATA_USER"
      usermod -a -G users "$LIMA_CIDATA_USER"

      ln -fs /run/current-system/sw/bin/bash /bin/bash

      # Create authorized_keys from Lima user-data
      LIMA_CIDATA_SSHDIR="$LIMA_CIDATA_HOME/.ssh"
      mkdir -p "$LIMA_CIDATA_SSHDIR"
      chmod 700 "$LIMA_CIDATA_SSHDIR"
      awk '
        match($0, /^([[:space:]]*)ssh-authorized-keys:/, m) { ident="^" m[1] "[[:space:]]+-[[:space:]]+"; flag=1; next }
        flag && $0 !~ ident { flag=0; next }
        flag && $0 ~ ident { sub(ident, ""); gsub("\"", ""); print $0 }
      ' "${LIMA_CIDATA_MNT}/user-data" > "$LIMA_CIDATA_SSHDIR/authorized_keys"
      LIMA_CIDATA_GID=$(id -g "$LIMA_CIDATA_USER")
      chown -R "$LIMA_CIDATA_UID:$LIMA_CIDATA_GID" "$LIMA_CIDATA_SSHDIR"
      chmod 600 "$LIMA_CIDATA_SSHDIR/authorized_keys"

      mkdir -p /etc/ssh/authorized_keys.d
      chmod 700 /etc/ssh/authorized_keys.d
      cp "$LIMA_CIDATA_SSHDIR/authorized_keys" "/etc/ssh/authorized_keys.d/$LIMA_CIDATA_USER"

      # Add Lima mounts to /etc/fstab
      sed -i '/#LIMA-START/,/#LIMA-END/d' /etc/fstab
      {
        echo "#LIMA-START"
        awk -f ${fstabAwk} "${LIMA_CIDATA_MNT}/user-data"
        echo "#LIMA-END"
      } >> /etc/fstab

      # Run system provisioning scripts
      if [ -d "${LIMA_CIDATA_MNT}/provision.system" ]; then
        for f in "${LIMA_CIDATA_MNT}/provision.system/"*; do
          echo "Executing $f"
          "$f" || echo "Failed to execute $f"
        done
      fi

      # Run user provisioning scripts
      USER_SCRIPT="$LIMA_CIDATA_HOME/.lima-user-script"
      if [ -d "${LIMA_CIDATA_MNT}/provision.user" ]; then
        until [ -e "/run/user/$LIMA_CIDATA_UID/systemd/private" ]; do sleep 3; done
        params=$(grep -o '^PARAM_[^=]*' "${LIMA_CIDATA_MNT}/param.env" | paste -sd ,) || params=""
        for f in "${LIMA_CIDATA_MNT}/provision.user/"*; do
          echo "Executing $f as $LIMA_CIDATA_USER"
          cp "$f" "$USER_SCRIPT"
          chown "$LIMA_CIDATA_USER" "$USER_SCRIPT"
          chmod 755 "$USER_SCRIPT"
          /run/wrappers/bin/sudo -iu "$LIMA_CIDATA_USER" \
            "--preserve-env=$params" \
            "XDG_RUNTIME_DIR=/run/user/$LIMA_CIDATA_UID" \
            "$USER_SCRIPT" || echo "Failed to execute $f as $LIMA_CIDATA_USER"
          rm "$USER_SCRIPT"
        done
      fi

      systemctl daemon-reload
      systemctl restart local-fs.target

      # Lima >= 2.1.0 expects the instance ID in signal files; older versions expect meta-data
      if [ -n "''${LIMA_CIDATA_IID:-}" ]; then
        echo "$LIMA_CIDATA_IID" > /run/lima-ssh-ready
        echo "$LIMA_CIDATA_IID" > /run/lima-boot-done
      else
        cp "${LIMA_CIDATA_MNT}/meta-data" /run/lima-ssh-ready
        cp "${LIMA_CIDATA_MNT}/meta-data" /run/lima-boot-done
      fi
    '';
  };
in
{
  options.services.lima.enable = lib.mkEnableOption "lima-init, lima-guestagent, other Lima support";

  config = lib.mkIf cfg.enable {
    systemd.services.lima-init = {
      description = "Reconfigure the system from lima-init userdata on startup";

      wantedBy = [ "multi-user.target" ];
      after = [ "network-pre.target" ];

      restartIfChanged = false;
      unitConfig.X-StopOnRemoval = false;

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${limaInit}/bin/lima-init";
        EnvironmentFile = "${LIMA_CIDATA_MNT}/lima.env";
      };
    };

    systemd.services.lima-guestagent = {
      description = "Forward ports to the lima-hostagent";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "lima-init.service"
      ];
      requires = [ "lima-init.service" ];
      script = ''
        ${LIMA_CIDATA_MNT}/lima-guestagent daemon --vsock-port "$LIMA_CIDATA_VSOCK_PORT"
      '';
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        EnvironmentFile = "${LIMA_CIDATA_MNT}/lima.env";
      };
    };

    fileSystems."${LIMA_CIDATA_MNT}" = {
      device = "${LIMA_CIDATA_DEV}";
      fsType = "iso9660";
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
