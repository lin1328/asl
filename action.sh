MODDIR=${0%/*}
PORT=$(sed -n 's/^PORT=\([0-9]*\)$/\1/p' "$MODDIR/config.ini")
PID=$("$MODDIR/bin/fuser" "$PORT/tcp" 2>/dev/null)

BATE() {
    local PREFIX="/data/user/0/com.termux/files/usr"
    local TBIN="$PREFIX/bin"
    local BASH="$TBIN/bash"
    local TMPDIR="$PREFIX/tmp"
    local BATE="$TMPDIR/asl.sh"

    if [ ! -d "$PREFIX" ]; then
        echo "- Termux 的环境异常"
        return
    fi

    cp -f "$MODDIR/bate.sh" "$BATE"
    chmod 755 "$BATE"

    echo "- 将在 Termux 中运行 请确保网络正常"
    echo "- 检查 Termux 是否在后台运行"
    echo "！温馨提示：如果未跳转到Termux页面，请下拉通知栏点击 Termux 进入 Termux 应用里"

    pidof com.termux &>/dev/null
    if [[ $? = 0 ]]; then
        echo "- 已在运行中"
        sleep 3
    else
        echo "- 正在打开 Termux"
        sleep 1
        $TBIN/am start -n com.termux/com.termux.app.TermuxActivity >/dev/null
        sleep 3
        pidof com.termux &>/dev/null || echo "！打开Termux应用失败，请手动打开"
    fi

    $TBIN/am startservice \
        -n com.termux/com.termux.app.TermuxService \
        -a com.termux.service_execute \
        -d com.termux.file:$BATE \
        -e com.termux.execute.background true >/dev/null

    echo "- 等待 Termux 完成安装..."
}

update_ssh() {
    local rootfs=$(grep '^LXC_OS_DIR=' "$MODDIR/config.ini" | cut -d '=' -f 2)

    sleep 2
    # 不确定是否所有设备通用，若有问题可能会考虑删除
    if lsof | grep "$rootfs" | awk '{print $2}' | uniq | grep -q "sshd"; then
        sed -i 's|^description=.*|description=\[ 运行中 😉 \] Android Subsystem for GNU/Linux Powered by ruri|' "$MODDIR/module.prop"
    else
        sed -i 's|^description=.*|description=\[ SSH 异常 ⚠️ \] Android Subsystem for GNU/Linux Powered by ruri|' "$MODDIR/module.prop"
    fi
}

if [ -n "$PID" ]; then
    printf "- 停止容器...\n\n"
    "$MODDIR"/container_ctrl.sh stop
    sed -i 's|^description=.*|description=\[ 已停止 🙁 \] Android Subsystem for GNU/Linux Powered by ruri|' "$MODDIR/module.prop"

    BATE
else
    printf "- 启动容器...\n\n"
    "$MODDIR"/container_ctrl.sh start

    update_ssh
fi

countdown=3
while [ $countdown -gt 0 ]; do
    printf "\r- %d" "$countdown"
    sleep 1
    countdown=$((countdown - 1))
done
