#!/bin/sh

init_setup() {
    MODDIR=${0%/*}
    export PATH="$MODDIR/bin:$PATH"
    . "$MODDIR/config.ini"
}

ruriumount() {
    init_setup

    # fuser -k "$LXC_OS_DIR" >/dev/null 2>&1  # 用于查找指定目录下的进程并终止这些进程

    PROCESS=$(ruri -P $LXC_OS_DIR)      # 若异常请更换另外一个函数或使用fuser
    if [ -n "$PROCESS" ]; then
        sorted_pids=$(echo "$PROCESS" | awk '{for(i=1;i<=NF;i++) if ($i ~ /^[0-9]+$/) print $i}' | sort -nr)

        echo "$sorted_pids" | while IFS= read -r PID; do
            if [ -n "$PID" ]; then
                kill -15 "$PID" 2>/dev/null || true
                sleep 1

                if ps -p "$PID" > /dev/null 2>&1; then
                    kill -9 "$PID" 2>/dev/null || true
                    echo "- 强制终止进程 ${PID}"
                else
                    echo "- 进程 ${PID} 已正常终止"
                fi
            fi
        done
    # else
    #     echo "容器没有正在运行的进程"
    fi

    ruri -U "$LXC_OS_DIR" >/dev/null 2>&1
    umount -lvf "$LXC_OS_DIR" 2>/dev/null
    umount -lf "$LXC_OS_DIR/sdcard" 2>/dev/null
    umount -lf "$LXC_OS_DIR/sys" 2>/dev/null
    umount -lf "$LXC_OS_DIR/proc" 2>/dev/null
    umount -lf "$LXC_OS_DIR/dev" 2>/dev/null
    sleep 2
}

unmount() {
    pids=$(lsof | grep "$LXC_OS_DIR" | awk '{print $2}' | uniq)
    if [ -n "$pids" ]; then
        echo "$pids" | while IFS= read -r pid; do
            if [ -n "$pid" ]; then
                kill -9 "$pid" 2>/dev/null || true
            fi
        done
    fi

    awk '{print $2}' /proc/mounts | grep "^$LXC_OS_DIR" | sort -r | while IFS= read -r umount_dir; do
        umount -f "$umount_dir" 2>/dev/null || {
            echo "无法卸载 $umount_dir" >&2
        }
    done
}

ruristart() {
    ruriumount

    case "$LXC_OS" in
        archlinux|centos|fedora)
            # e.g. /usr/sbin/sshd
            START_SERVICES="servicectl start sshd"
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
        mount --bind "$LXC_OS_DIR" "$LXC_OS_DIR"
        mount -o remount,suid "$LXC_OS_DIR"
    fi
    
    ARGS="-w"
    
    if [ -n "$MOUNT_POINT" ] && [ -n "$MOUNT_ENTRANCE" ]; then
        if [ "$MOUNT_READ_ONLY" = "true" ]; then
            ARGS="$ARGS -M $MOUNT_POINT $MOUNT_ENTRANCE"
        else
            ARGS="$ARGS -m $MOUNT_POINT $MOUNT_ENTRANCE"
        fi
        # [ ! -d "$LXC_OS_DIR/$MOUNT_ENTRANCE" ] && mkdir -p "$LXC_OS_DIR/$MOUNT_ENTRANCE"
    fi
    
    [ "$UNMASK_DIRS" = "true" ] && ARGS="$ARGS -A"
    [ "$PRIVILEGED" = "true" ] && ARGS="$ARGS -p"
    [ "$RUNTIME" = "true" ] && ARGS="$ARGS -S"
    
    ARGS="$ARGS -f"
    
    set -- $ARGS "$LXC_OS_DIR" /usr/bin/env -i HOME=/root PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin TERM=linux SHELL=/bin/sh LANG=en_US.UTF-8 /bin/sh -c "$START_SERVICES"
    
    echo "- Command: ruri $(printf "%s " "$@")"
    
    ruri "$@" &
    # timeout 5s ruri "$@"
    
    # set -- $ARGS "$LXC_OS_DIR" /usr/bin/env -i HOME=/root PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin TERM=linux SHELL=/bin/sh LANG=en_US.UTF-8 /bin/sh -c "\"$START_SERVICES\""
    # COMMAND="ruri $(printf "%s " "$@")"
    # echo "Constructed Command: su -c \"$COMMAND\""
    # su -c "$COMMAND"
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
