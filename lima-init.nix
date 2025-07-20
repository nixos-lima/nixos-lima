{ config, modulesPath, pkgs, lib, ... }:

let
    LIMA_CIDATA_MNT = "/mnt/lima-cidata";
    LIMA_CIDATA_DEV = "/dev/disk/by-label/cidata";

    cfg = config.services.lima;

    script = ''
    echo "attempting to fetch configuration from LIMA user data..."

    if [ -f ${LIMA_CIDATA_MNT}/lima.env ]; then
        echo "storage exists";
    else
        echo "storage not exists";
        exit 2
    fi
    # ripped from https://github.com/lima-vm/alpine-lima/blob/main/lima-init.sh
    # We can't just source lima.env because values might have spaces in them
    while read -r line; do export "$line"; done <"${LIMA_CIDATA_MNT}"/lima.env

    export PATH=${pkgs.lib.makeBinPath [ pkgs.shadow pkgs.gawk pkgs.mount ]}:$PATH

    # Create user
    LIMA_CIDATA_HOMEDIR="/home/$LIMA_CIDATA_USER.linux"
    id -u "$LIMA_CIDATA_USER" >/dev/null 2>&1 || useradd --home-dir "$LIMA_CIDATA_HOMEDIR" --create-home --uid "$LIMA_CIDATA_UID" "$LIMA_CIDATA_USER"

    # Add user to sudoers
    usermod -a -G wheel $LIMA_CIDATA_USER
    usermod -a -G users $LIMA_CIDATA_USER

    echo "fix symlink for /bin/bash"
    ln -fs /run/current-system/sw/bin/bash /bin/bash

    # Create authorized_keys
    LIMA_CIDATA_SSHDIR="$LIMA_CIDATA_HOMEDIR"/.ssh
    mkdir -p -m 700 "$LIMA_CIDATA_SSHDIR"
    awk '/ssh-authorized-keys/ {flag=1; next} /^ *$/ {flag=0} flag {sub(/^ +- /, ""); gsub("\"", ""); print $0}' \
    "${LIMA_CIDATA_MNT}"/user-data >"$LIMA_CIDATA_SSHDIR"/authorized_keys
    LIMA_CIDATA_GID=$(id -g "$LIMA_CIDATA_USER")
    chown -R "$LIMA_CIDATA_UID:$LIMA_CIDATA_GID" "$LIMA_CIDATA_SSHDIR"
    chmod 600 "$LIMA_CIDATA_SSHDIR"/authorized_keys

    LIMA_SSH_KEYS_CONF=/etc/ssh/authorized_keys.d
    mkdir -p -m 700 "$LIMA_SSH_KEYS_CONF"
    cp "$LIMA_CIDATA_SSHDIR"/authorized_keys "$LIMA_SSH_KEYS_CONF/$LIMA_CIDATA_USER"

    # Add mounts to /etc/fstab
    echo "Adding mounts to /etc/fstab"
    sed -i '/#LIMA-START/,/#LIMA-END/d' /etc/fstab
    echo "#LIMA-START" >> /etc/fstab
    awk -f- "${LIMA_CIDATA_MNT}"/user-data <<'EOF' >> /etc/fstab
    /^mounts:/ {
        flag = 1
        next
    }
    /^[^:]*:/ {
        flag = 0
    }
    /^ *$/ {
        flag = 0
    }
    flag {
        sub(/^ *- \[/, "")
        sub(/"?\] *$/, "")
        gsub("\"?, \"?", "\t")
        print $0
    }
EOF
    echo "#LIMA-END" >> /etc/fstab

    # Run system provisioning scripts
    echo "Running system provisioning scripts"
    if [ -d "${LIMA_CIDATA_MNT}"/provision.system ]; then
    	for f in "${LIMA_CIDATA_MNT}"/provision.system/*; do
    		echo "Executing $f"
    		if ! "$f"; then
    			echo "Failed to execute $f"
    		fi
    	done
    fi

    # Run user provisioning scripts
    echo "Running user provisioning scripts"
    USER_SCRIPT="$LIMA_CIDATA_HOME/.lima-user-script"
    if [ -d "${LIMA_CIDATA_MNT}"/provision.user ]; then
        if [ ! -f /sbin/openrc-run ]; then
            until [ -e "/run/user/$LIMA_CIDATA_UID/systemd/private" ]; do sleep 3; done
        fi
        params=$(grep -o '^PARAM_[^=]*' "${LIMA_CIDATA_MNT}"/param.env | paste -sd ,)
        for f in "${LIMA_CIDATA_MNT}"/provision.user/*; do
            echo "Executing $f (as user $LIMA_CIDATA_USER)"
            cp "$f" "$USER_SCRIPT"
            chown "$LIMA_CIDATA_USER" "$USER_SCRIPT"
            chmod 755 "$USER_SCRIPT"
            if ! /run/wrappers/bin/sudo -iu "$LIMA_CIDATA_USER" "--preserve-env=$params" "XDG_RUNTIME_DIR=/run/user/$LIMA_CIDATA_UID" "$USER_SCRIPT"; then
                echo "Failed to execute $f (as user $LIMA_CIDATA_USER)"
            fi
            rm "$USER_SCRIPT"
        done
    fi


    systemctl daemon-reload
    systemctl restart local-fs.target

    #echo "$LIMA_CIDATA_SLIRP_GATEWAY host.lima.internal" >> /etc/hosts

    cp "${LIMA_CIDATA_MNT}"/meta-data /run/lima-ssh-ready
    cp "${LIMA_CIDATA_MNT}"/meta-data /run/lima-boot-done
    exit 0
    '';
in {
    imports = [];

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

        systemd.services.lima-guestagent =  {
            enable = true;
            description = "Forward ports to the lima-hostagent";
            wantedBy = [ "multi-user.target" ];
            after = [ "network.target" "lima-init.service" ];
            requires = [ "lima-init.service" ];
            serviceConfig = {
                Type = "simple";
                ExecStart = "${LIMA_CIDATA_MNT}/lima-guestagent daemon";
                Restart = "on-failure";
            };
        };

        fileSystems."${LIMA_CIDATA_MNT}" = {
            device = "${LIMA_CIDATA_DEV}";
            fsType = "auto";
            options = [ "ro" "mode=0700" "dmode=0700" "overriderockperm" "exec" "uid=0" ];
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

