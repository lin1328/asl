#!/bin/sh
MODULEID="asl"
MODULEDIR="/data/adb/modules/$MODULEID"

if command -v magisk >/dev/null 2>&1; then
    if magisk -v | grep -q lite; then
        MODULEDIR="/data/adb/lite_modules/$MODULEID"
    fi
fi

while [ $(getprop sys.boot_completed) != 1 ]; do
    sleep 2
done

[ ! -f "$MODULEDIR/disable" ] && "$MODULEDIR/container_ctrl.sh" start

(
    inotifyd - "$MODULEDIR" 2>/dev/null | while read -r events _ file; do
        if [ "$file" = "disable" ]; then
            case "$events" in
                d)
                    "$MODULEDIR/container_ctrl.sh" start
                    ;;
                n)
                    "$MODULEDIR/container_ctrl.sh" stop
                    ;;
                *)
                    :
                    ;;
            esac
        fi
    done
) &
pid=$!

sed -i "6c description=[ PID=$pid ] This container can be quickly controlled by enabling/disabling" "$MODULEDIR/module.prop"
