#!/bin/sh
MODULEID="moduleid"
MODULEDIR="/data/adb/modules/$MODULEID"
DESCRIPTION="Android Subsystem for GNU/Linux Powered by ruri"

if command -v magisk 2>&1 >/dev/null; then
    if magisk -v | grep -q lite; then
        MODULEDIR="/data/adb/lite_modules/$MODULEID"
    fi
fi

while [ $(getprop sys.boot_completed) != 1 ]; do
    sleep 2
done

# [ ! -f "$MODULEDIR"/disable ] && "$MODULEDIR"/start.sh

(
    inotifyd - "$MODULEDIR" 2>/dev/null |
        while read events dir file; do
            # echo "$events $dir $file" >> debug.log
            if [ "$file" = "disable" ]; then
                NOW=$(TZ='Asia/Shanghai' date +"%m-%d %H:%M:%S %Z")
                case "$events" in
                d)
                    "$MODULEDIR"/start.sh
                    sed -i "6cdescription=[ on : $NOW ] $DESCRIPTION" "$MODULEDIR"/module.prop
                    ;;
                n)
                    "$MODULEDIR"/stop.sh
                    sed -i "6cdescription=[ off : $NOW ] $DESCRIPTION" "$MODULEDIR"/module.prop
                    ;;
                *)
                    :
                    ;;
                esac
            fi
        done
) &

pid=$!
echo "$pid" > "$MODULEDIR"/.pidfile

(
    sleep 15
    rm -f "$MODULEDIR"/.pidfile
) &


sed -i "6cdescription=[ inotify-pid=$pid ] Start/stop the container in real-time through this module" "$MODULEDIR"/module.prop
