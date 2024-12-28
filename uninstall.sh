MODDIR=${0%/*}
"$MODDIR/container_ctrl.sh" stop

delete_container() {
    local LXC_OS_DIR=$(grep '^LXC_OS_DIR=' "$MODDIR/config.ini" | cut -d '=' -f 2)

    rm -f /data/adb/service.d/service.sh

    if [ -d "$LXC_OS_DIR" ]; then
        rm -rf "$LXC_OS_DIR"
    fi

    for BACKUP_DIR in "$LXC_OS_DIR".old*; do
        if [ -e "$BACKUP_DIR" ]; then
            rm -rf "$BACKUP_DIR"
        fi
    done
}

delete_container
