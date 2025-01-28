#!/bin/sh

. "${0%/*}/config.conf"

if [ ! -e "$CONTAINER_DIR/etc/os-release" ]; then
    exit 1
fi

ruriumount() {
    fuser -k "$CONTAINER_DIR" >/dev/null 2>&1
    ruri -U "$CONTAINER_DIR" >/dev/null 2>&1
    umount -lvf "$CONTAINER_DIR" 2>/dev/null
    umount -lf "$CONTAINER_DIR/sdcard" 2>/dev/null
    umount -lf "$CONTAINER_DIR/sys" 2>/dev/null
    umount -lf "$CONTAINER_DIR/proc" 2>/dev/null
    umount -lf "$CONTAINER_DIR/dev" 2>/dev/null
    sleep 2
}

ruristart() {
    ruriumount

    case "$RURIMA_LXC_OS" in
        archlinux|centos|fedora)
            START_SERVICES="servicectl start sshd"
            # you can opt for other startup commands It is not mandatory
            # e.g. /usr/sbin/sshd
            ;;
        debian|kali|ubuntu)
            START_SERVICES="service ssh start"
            ;;
        alpine)
            START_SERVICES="rc-service sshd restart"
            ;;
        *)
            START_SERVICES=""
            ;;
    esac

    if [ "$REQUIRE_SUDO" = "true" ]; then
        mount --bind $CONTAINER_DIR $CONTAINER_DIR
        mount -o remount,suid $CONTAINER_DIR
    fi

    ARGS="-w"

    if [ -n "$MOUNT_POINT" ] && [ -n "$MOUNT_ENTRANCE" ]; then
        if [ "$MOUNT_READ_ONLY" = "true" ]; then
            ARGS="$ARGS -M $MOUNT_POINT $MOUNT_ENTRANCE"
        else
            ARGS="$ARGS -m $MOUNT_POINT $MOUNT_ENTRANCE"
        fi
    fi
    # [ ! -d "$CONTAINER_DIR/$MOUNT_ENTRANCE" ] && mkdir -p "$CONTAINER_DIR/$MOUNT_ENTRANCE"

    [ "$UNMASK_DIRS" = "true" ] && ARGS="$ARGS -A"
    [ "$PRIVILEGED" = "true" ] && ARGS="$ARGS -p"
    [ "$RUNTIME" = "true" ] && ARGS="$ARGS -S"

    ruri $ARGS "$CONTAINER_DIR" /bin/sh -c "$START_SERVICES" &
}

case "$1" in
    start)
        ruristart
        ;;
    stop)
        ruriumount
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        exit 1
        ;;
esac
