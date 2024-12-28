SKIPUNZIP=1
ASH_STANDALONE=0
REPLACE=""

bootinspect() {
    if [ "$BOOTMODE" ] && [ "$KSU" ]; then
        ui_print "- Install from KernelSU"
        ui_print "- KernelSU Version：$KSU_KERNEL_VER_CODE（App）+ $KSU_VER_CODE（ksud）"
    elif [ "$BOOTMODE" ] && [ "$APATCH" ]; then
        ui_print "- Install from APatch"
        ui_print "- Apatch Version：$APATCH_VER_CODE（App）+ $KERNELPATCH_VERSION（KernelPatch）"
    elif [ "$BOOTMODE" ] && [ "$MAGISK_VER_CODE" ]; then
        ui_print "- Install from Magisk"
        ui_print "- Magisk Version：$MAGISK_VER（App）+ $MAGISK_VER_CODE"
    else
        abort "! 不支持的安装模式。请从应用程序中安装 (Magisk/KernelSu/Apatch)"
    fi
    if [ "$ARCH" != "arm64" ]; then
        abort "! 不支持的平台: $ARCH"
    else
        ui_print "- 设备平台: $ARCH"
    fi
}

basefile() {
    unzip -qo "$ZIPFILE" -x 'META-INF/*' -d "$MODPATH" >&2

    rm -rf \
        "$MODPATH/customize.sh" \
        "$MODPATH"/*.md \
        "$MODPATH"/.git* \
        "$MODPATH/LICENSE" 2>/dev/null
}

link_busybox() {
    local busybox_file=""

    if [ -f "$MODPATH/system/xbin/busybox" ]; then
        busybox_file="$MODPATH/system/xbin/busybox"
    else
        for path in $BUSYBOX_PATHS; do
            if [ -f "$path" ]; then
                busybox_file="$path"
                break
            fi
        done
    fi

    if [ -n "$busybox_file" ]; then
        mkdir -p "$MODPATH/system/xbin"
        # "$busybox_file" --install -s "$MODPATH/system/xbin"
        # 这种方法会创建指向 BusyBox 所有命令的链接，因此不推荐使用。以下是一种替代方法，用于为特定命令创建指向 BusyBox 文件的符号链接
        for cmd in fuser xz gzip timeout; do
            ln -sf "$busybox_file" "$MODPATH/system/xbin/$cmd"
        done

        if ! inotifyd --help >/dev/null 2>&1; then
            ln -sf "$busybox_file" "$MODPATH/system/xbin/inotifyd"
        fi
    else
        abort "! 未找到可用的 Busybox 文件。请检查您的安装环境"
    fi
}

inotifyfile() {
    local id_value
    id_value=$(sed -n 's/^id=\(.*\)$/\1/p' "$MODPATH/module.prop")
    local MONITORFILE=".${id_value}.service.sh"

    sed -i "2c MODULEID=\"$id_value\"" "$MODPATH/service.sh"
    mkdir -p /data/adb/service.d
    mv -f "$MODPATH/service.sh" "/data/adb/service.d/$MONITORFILE"
    chmod +x "/data/adb/service.d/$MONITORFILE"

    sed -i "s/service.sh/$MONITORFILE/g" "$MODPATH/uninstall.sh"
}

configuration() {
    # install -m 755 -o root -g root "$MODPATH/bin/ruri" /system/bin/
    set_perm_recursive "$MODPATH/system/xbin" 0 0 0755 0755
    . "$MODPATH/config.ini"

    BUSYBOX_PATHS="/data/adb/magisk/busybox /data/adb/ksu/bin/busybox /data/adb/ap/bin/busybox"

    CONTAINER_DIR="/data/lxc/$LXC_OS"
    sed -i "s|^LXC_OS_DIR=.*|LXC_OS_DIR=$CONTAINER_DIR|" "$MODPATH/config.ini"
    
    CASE=$(sed -n '/case "[^"]*LXC_OS"/,/^[[:space:]]*esac/p' "$MODPATH/setup/setup.sh")
    
    SUPPORT=$(echo "$CASE" | sed -nE 's/^[[:space:]]*([a-zA-Z0-9_]+)[[:space:]]*\)[[:space:]]*.*$/\1/p' | tr '\n' ' ')
    
    if ! echo "$SUPPORT" | tr ' ' '\n' | grep -qx "$LXC_OS"; then
        abort "! setup.sh 不支持 $LXC_OS"
    fi

    MOUNTCOUNT=$(cat /proc/mounts | awk '{print $2}' | grep "^$CONTAINER_DIR" | sort -r | wc -l)

    if [ "$MOUNTCOUNT" -gt 0 ] || [ -f "$CONTAINER_DIR/.rurienv" ]; then
        ruri -U "$CONTAINER_DIR"
    fi

    if [ -d "$CONTAINER_DIR" ]; then
        if find "$CONTAINER_DIR" -mindepth 1 -print -quit >/dev/null 2>&1; then
            if [ -d "$CONTAINER_DIR.old" ]; then
                version=1
                while [ -d "$CONTAINER_DIR.old.$version" ]; do
                    version=$((version + 1))
                done
                mv "$CONTAINER_DIR.old" "$CONTAINER_DIR.old.$version"
            fi
            mv -f "$CONTAINER_DIR" "$CONTAINER_DIR.old"
            ui_print "- 停止容器并将主目录文件备份到 $CONTAINER_DIR.old"
        else
            rm -rf "$CONTAINER_DIR"
        fi
    fi
}

download_rootfs() {
    if [ ! -d "$CONTAINER_DIR" ]; then
        if ! mkdir -p "$CONTAINER_DIR"; then
            abort "! 无法创建目录 $CONTAINER_DIR"
        fi
    fi

    if [ ! -w "$CONTAINER_DIR" ]; then
        abort "! 对 $CONTAINER_DIR 目录没有写入权限"
    fi

    if [ -n "$LXC_OS_URL" ]; then
        local file_name save_path
        file_name=$(basename "$LXC_OS_URL")
        save_path="$TMPDIR/$file_name"

        ui_print "- 正在从 $LXC_OS_URL 下载根文件系统..."
        if curl -fSL "$LXC_OS_URL" -o "$save_path"; then
            case "$file_name" in
                *.tar.xz)
                    if tar -xJf "$save_path" -C "$CONTAINER_DIR"; then
                        rm -f "$save_path"
                    else
                        rm -rf "$CONTAINER_DIR"
                        abort "! 无法解压缩根文件系统"
                    fi
                    ;;
                *.tar.gz)
                    if tar -xzf "$save_path" -C "$CONTAINER_DIR"; then
                        rm -f "$save_path"
                    else
                        rm -rf "$CONTAINER_DIR"
                        abort "! 无法解压缩根文件系统"
                    fi
                    ;;
                *.tar.zst)
                    if tar -I zstd -xf "$save_path" -C "$CONTAINER_DIR"; then
                        rm -f "$save_path"
                    else
                        rm -rf "$CONTAINER_DIR"
                        abort "! 无法解压缩根文件系统"
                    fi
                    ;;
                *)
                    abort "! 不支持的文件格式：$file_name"
                    ;;
            esac
        else
            abort "! 无法下载根文件系统"
        fi
        return
    fi

    if [ -z "$LXC_OS" ] || [ -z "$LXC_OS_VERSION" ]; then
        abort "! config.ini 中未设置 LXC_OS 或 LXC_OS_VERSION"
    fi

    local mirrors="$LXC_MIRROR mirrors.tuna.tsinghua.edu.cn/lxc-images"
    local success=false
    local index_url rootfs_url save_path

    for mirror in $mirrors; do
        if ! echo "$mirror" | grep -qE '^https?://'; then
            mirror="https://$mirror"
        fi
        index_url="${mirror}/meta/1.0/index-system"

        rootfs_url=$(curl -fsSL "$index_url" | awk -F';' -v os="$LXC_OS" -v version="$LXC_OS_VERSION" -v arch="$ARCH" '
            $1 == os && $2 == version && $3 == arch && $4 == "default" { print $6 }' | head -n 1)

        if [ -n "$rootfs_url" ]; then
            rootfs_url="${mirror}${rootfs_url}rootfs.tar.xz"
            save_path="$TMPDIR/rootfs.tar.xz"

            ui_print "- 正在从 $rootfs_url 下载根文件系统..."
            if curl -fSL "$rootfs_url" -o "$save_path"; then
                if tar -xJf "$save_path" -C "$CONTAINER_DIR"; then
                    rm -f "$save_path"
                    success=true
                    break
                else
                    rm -rf "$CONTAINER_DIR"
                    abort "! 无法解压缩根文件系统"
                fi
            else
                abort "! 无法从镜像站 $mirror 下载根文件系统，尝试更换其他镜像站..."
            fi
        else
            abort "! 无法从镜像站 $mirror 解析索引，尝试更换其他镜像站..."
        fi
    done

    if [ "$success" = false ]; then
        abort "! 无法从镜像站下载根文件系统"
    fi
}

automatic() {
    ui_print "- 下载根文件系统需要网络连接 请尽可能在安装前连接到 WiFi"
    
    download_rootfs

    ui_print "- 启动 chroot 环境以执行自动安装..."
    ui_print "- 请确保网络环境稳定 此过程可能需要一些时间，请耐心等待!"
    ui_print ""
    sleep 1
    getprop ro.product.model > "$CONTAINER_DIR/etc/hostname"
    mkdir -p "$CONTAINER_DIR/tmp" "$CONTAINER_DIR/usr/local/lib/servicectl/enabled"
    cp "$MODPATH/setup/setup.sh" "$CONTAINER_DIR/tmp/setup.sh"
    cp -r "$MODPATH/setup/servicectl"/* "$CONTAINER_DIR/usr/local/lib/servicectl/"
    chmod 777 "$CONTAINER_DIR/tmp/setup.sh" "$CONTAINER_DIR/usr/local/lib/servicectl/servicectl" "$CONTAINER_DIR/usr/local/lib/servicectl/serviced"
    
    ruri -f "$CONTAINER_DIR" /usr/bin/env -i HOME=/root TMPDIR=/tmp PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin TERM=linux /bin/sh /tmp/setup.sh  "$LXC_OS" "$PASSWORD" "$PORT"

    inotifyfile

    ui_print "- 自动安装完成!"
    ui_print "- 请更改默认密码。使用密码身份验证而不是基于密钥的身份验证以及默认 SSH 端口始终是一种高风险行为!"
}

install() {
    :
}

main() {
    bootinspect
    basefile
    configuration
    link_busybox

    [ "$INSTALLATION" = "true" ] && automatic || install

    ruri -U "$CONTAINER_DIR"
}

main

# set_perm_recursive "$MODPATH" 0 0 0755 0644
# chmod ugo+x "$MODPATH/container_ctrl.sh"
set_perm "$MODPATH/container_ctrl.sh" 0 0 0755

ui_print ""
ui_print "- 请重新启系统"
