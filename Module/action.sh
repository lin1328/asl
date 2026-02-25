MODDIR=${0%/*}
PORT=$(grep "^PORT=" "$MODDIR/config.conf" | awk -F= '{print $2}')
PID=$(fuser "$PORT/tcp" 2>/dev/null)

update_ssh() {
    local rootfs=$(sed -n 's/^CONTAINER_DIR=\(.*\)$/\1/p' "$MODDIR/config.conf")

    sleep 2
    if lsof | grep "$rootfs" | awk '{print $2}' | uniq | grep -q "sshd"; then
        sed -i 's|^description=.*|description=\[ running😋 \] Android Subsystem for GNU/Linux Powered by ruri|' "$MODDIR/module.prop"
    else
        sed -i 's|^description=.*|description=\[ SSH exception⁉️ \] Android Subsystem for GNU/Linux Powered by ruri|' "$MODDIR/module.prop"
    fi
}

if [ -n "$PID" ]; then
    printf "- Stopping container...\n\n"
    if "$MODDIR/container_ctrl.sh" stop; then
        sed -i 's|^description=.*|description=\[ stopped😴 \] Android Subsystem for GNU/Linux Powered by ruri|' "$MODDIR/module.prop"
    fi
else
    printf "- Starting up container...\n\n"
    if "$MODDIR/container_ctrl.sh" start; then
        update_ssh
    fi
fi

countdown=3
while [ $countdown -gt 0 ]; do
    printf "\r- %d" "$countdown"
    sleep 1
    countdown=$((countdown - 1))
done
