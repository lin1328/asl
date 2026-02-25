MODDIR=${0%/*}
"$MODDIR/container_ctrl.sh" stop
CONTAINER_DIR=$(grep '^CONTAINER_DIR=' "$MODDIR/config.conf" | cut -d '=' -f 2)

rm -f /data/adb/service.d/inotify.sh
umount -lf "$CONTAINER_DIR/dev"
umount -lf "$CONTAINER_DIR/proc"
umount -lf "$CONTAINER_DIR/sys"
umount -lf "$CONTAINER_DIR/sdcard"
rm -rf "$CONTAINER_DIR"
version=1
while [ -d "${CONTAINER_DIR}_${version}" ]; do
    rm -rf "${CONTAINER_DIR}_${version}"
    version=$((version + 1))
done
