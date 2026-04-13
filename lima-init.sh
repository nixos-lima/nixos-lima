echo "attempting to fetch configuration from LIMA user data..."

if [ -f @limaCidataMnt@/lima.env ]; then
    echo "storage exists";
else
    echo "storage not exists";
    exit 2
fi
# ripped from https://github.com/lima-vm/alpine-lima/blob/main/lima-init.sh
# We can't just source lima.env because values might have spaces in them
while read -r line; do export "$line"; done <"@limaCidataMnt@"/lima.env

export PATH=@binPath@:$PATH

# Create user
id -u "$LIMA_CIDATA_USER" >/dev/null 2>&1 || useradd --home-dir "$LIMA_CIDATA_HOME" --create-home --uid "$LIMA_CIDATA_UID" "$LIMA_CIDATA_USER"

# Add user to sudoers
usermod -a -G wheel $LIMA_CIDATA_USER
usermod -a -G users $LIMA_CIDATA_USER

echo "fix symlink for /bin/bash"
ln -fs /run/current-system/sw/bin/bash /bin/bash

# Create authorized_keys
LIMA_CIDATA_SSHDIR="$LIMA_CIDATA_HOME"/.ssh
mkdir -p -m 700 "$LIMA_CIDATA_SSHDIR"
awk '
match($0, /^([[:space:]]*)ssh-authorized-keys:/, m) { ident="^" m[1] "[[:space:]]+-[[:space:]]+"; flag=1; next }
flag && $0 !~ ident { flag=0; next }
flag && $0 ~ ident { sub(ident, ""); gsub("\"", ""); print $0 }
' "@limaCidataMnt@"/user-data >"$LIMA_CIDATA_SSHDIR"/authorized_keys
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
awk -f- "@limaCidataMnt@"/user-data <<'EOF' >> /etc/fstab
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
if [ -d "@limaCidataMnt@"/provision.system ]; then
for f in "@limaCidataMnt@"/provision.system/*; do
    echo "Executing $f"
    if ! "$f"; then
        echo "Failed to execute $f"
    fi
done
fi

# Run user provisioning scripts
echo "Running user provisioning scripts"
USER_SCRIPT="$LIMA_CIDATA_HOME/.lima-user-script"
if [ -d "@limaCidataMnt@"/provision.user ]; then
    if [ ! -f /sbin/openrc-run ]; then
        until [ -e "/run/user/$LIMA_CIDATA_UID/systemd/private" ]; do sleep 3; done
    fi
    params=$(grep -o '^PARAM_[^=]*' "@limaCidataMnt@"/param.env | paste -sd ,)
    for f in "@limaCidataMnt@"/provision.user/*; do
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

# write instance ID to boot-done and ssh-ready signal files for Lima (>= 2.1.0)
if [ -n "$LIMA_CIDATA_IID" ]; then
    echo "$LIMA_CIDATA_IID" > /run/lima-ssh-ready
    echo "$LIMA_CIDATA_IID" > /run/lima-boot-done
else
    cp "@limaCidataMnt@"/meta-data /run/lima-ssh-ready
    cp "@limaCidataMnt@"/meta-data /run/lima-boot-done
fi

exit 0
