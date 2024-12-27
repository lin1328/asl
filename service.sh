#!/bin/sh
MODULEID="moduleid"
MODULEDIR="/data/adb/modules/$MODULEID"

if command -v magisk > /dev/null 2>&1; then
    if magisk -v | grep -q lite; then
        MODULEDIR="/data/adb/lite_modules/$MODULEID"
    fi
fi

while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done

if [ ! -f "$MODULEDIR/disable" ]; then
    "$MODULEDIR/container_ctrl.sh" start
fi

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

echo "$pid" > "$MODULEDIR/.pidfile"
(
    sleep 15
    rm -f "$MODULEDIR/.pidfile"
) &

sed -i "6c description=[ PID=$pid ] 可通过启用/禁用模块来快速控制容器 可能存在未知错误，不保证兼容所有机型" "$MODULEDIR/module.prop"


# while read -r line; do
#     # echo "test line: $line" >> debug.log
#     events=$(echo "$line" | awk '{print $1}')
#     monitor_dir=$(echo "$line" | awk '{print $2}')
#     monitor_file=$(echo "$line" | awk '{print $3}')
#
#     if [ "$monitor_file" = "disable" ]; then
#         case "$events" in
#             d)
#                 su -c "sh $MODULEDIR/start.sh"
#                 ;;
#             n)
#                 su -c "sh $MODULEDIR/stop.sh"
#                 ;;
#             *)
#                 :
#                 ;;
#         esac
#     fi
# done < <(inotifyd - "$MODULEDIR" 2>/dev/null) &