SKIPUNZIP=0

ASL=""
REPLACE=""

BASE_DIR="/data"

bootinspect() {
    if [ "$BOOTMODE" ] && [ "$KSU" ]; then
        ui_print "- Install from KernelSU"
        ui_print "- KernelSU Version: $KSU_KERNEL_VER_CODE (App) + $KSU_VER_CODE (ksud)"
    elif [ "$BOOTMODE" ] && [ "$APATCH" ]; then
        ui_print "- Install from APatch"
        ui_print "- Apatch Version: $APATCH_VER_CODE (App)"
    elif [ "$BOOTMODE" ] && [ "$MAGISK_VER_CODE" ]; then
        ui_print "- Install from Magisk"
        ui_print "- Magisk Version: $MAGISK_VER (App) + $MAGISK_VER_CODE"
    else
        abort "- Unsupported installation mode. Please install from the application (Magisk/KernelSu/Apatch)"
    fi
    [ "$ARCH" != "arm64" ] && abort "- Unsupported platform: $ARCH" || ui_print "- Device platform: $ARCH"
}

link_busybox() {
    local busybox_file=""
    local BUSYBOX_PATHS="/data/adb/magisk/busybox /data/adb/ksu/bin/busybox /data/adb/ap/bin/busybox"

    for path in $BUSYBOX_PATHS; do
        if [ -f "$path" ]; then
            busybox_file="$path"
            break
        fi
    done

    if [ -n "$busybox_file" ]; then
        mkdir -p "$MODPATH/system/xbin"
        # "$busybox_file" --install -s "$MODPATH/system/xbin"
        # This method creates links pointing to all commands of busybox, so it is not recommended. The following is an alternative approach for creating symbolic links pointing to the busybox file for specific commands
        for cmd in fuser; do
            ln -sf "$busybox_file" "$MODPATH/system/xbin/$cmd"
        done

        if ! command -v inotifyd >/dev/null 2>&1; then
            ln -sf "$busybox_file" "$MODPATH/system/xbin/inotifyd"
        fi
    else
        abort "- No available Busybox file found Please check your installation environment"
    fi

    set_perm_recursive "$MODPATH/system/xbin" 0 0 0755 0755
    export PATH="$MODPATH/system/xbin:$PATH"
}

inotifyfile() {
    id_value=$(grep "^id=" "$MODPATH/module.prop" | awk -F= '{print $2}')
    MONITORFILE=".${id_value}.service.sh"

    sed -i "2c MODULEID=\"$id_value\"" "$MODPATH/inotify.sh"
    mkdir -p /data/adb/service.d
    mv -f "$MODPATH/inotify.sh" "/data/adb/service.d/$MONITORFILE"
    chmod +x "/data/adb/service.d/$MONITORFILE"

    sed -i "s/inotify.sh/$MONITORFILE/g" "$MODPATH/uninstall.sh"
}

configuration() {
    . "$MODPATH/config.conf"

    CONTAINER_DIR="${BASE_DIR}/${LXC_OS}"
    sed -i "s|^CONTAINER_DIR=.*|CONTAINER_DIR=$CONTAINER_DIR|" "$MODPATH/config.conf"

    SUPPORT=$(grep "^OS_LIST=" "$MODPATH/setup/setup.sh" | awk -F'"' '{print $2}')

    if ! echo "$SUPPORT" | grep -qw "$LXC_OS"; then
        abort "- $LXC_OS is not supported by the setup script"
    fi

    if [ -d "$CONTAINER_DIR" ]; then
        ui_print "- Already installed"
        ruri -U "$CONTAINER_DIR"

        version=1
        while [ -d "${CONTAINER_DIR}_${version}" ]; do
            version=$((version + 1))
        done

        mv -f "$CONTAINER_DIR" "${CONTAINER_DIR}_${version}"
        ui_print "- Shut down the container and backed up to ${CONTAINER_DIR}_${version}"
    fi
}

normalize_url() {
    case "$1" in
        http://*|https://*) echo "$1" ;;
        *) echo "https://$1" ;;
    esac
}

get_rootfs_path() {
    local json_url="$1"
    curl -s "$json_url" | \
        jq -r \
        --arg key "${LXC_OS}:${LXC_OS_VERSION}:arm64:default" \
        '.products[$key].versions
        | to_entries
        | sort_by(.key)
        | last
        | .value.items["root.tar.xz"].path'
}

try_mirror() {
    local base_url rootfs_path
    base_url=$(normalize_url "$1")

    rootfs_path=$(get_rootfs_path "${base_url}/meta/simplestreams/v1/images.json")
    if [ -z "$rootfs_path" ] || [ "$rootfs_path" = "null" ]; then
        return 1
    fi

    # ui_print "- Downloading: ${base_url}/${rootfs_path}  Extracting to: ${CONTAINER_DIR}"
    mkdir -p "$CONTAINER_DIR"
    curl -fL "${base_url}/${rootfs_path}" | tar -xJ -C "$CONTAINER_DIR"
}

automatic() {
    ui_print "- A network connection is required to download the root filesystem. Please connect to WiFi before installation whenever possible"
    ui_print "- Fetching image list from ${LXC_MIRROR}..."

    if ! try_mirror "$LXC_MIRROR"; then
        ui_print "- Primary mirror failed, trying fallback: ${LXC_MIRROR_FALLBACK}..."
        if ! try_mirror "$LXC_MIRROR_FALLBACK"; then
            abort "No rootfs found for ${LXC_OS} ${LXC_OS_VERSION} arm64 or other error" >&2
        fi
    fi

    ui_print "- Starting the chroot environment to perform automated installation..."
    ui_print "- Please ensure the network environment is stable. The process may take some time, so please be patient!"
    ui_print ""
    sleep 2
    getprop ro.product.model > "$CONTAINER_DIR/etc/hostname"
    mkdir -p "$CONTAINER_DIR/tmp" "$CONTAINER_DIR/usr/local/lib/servicectl/enabled"
    cp "$MODPATH/setup/setup.sh" "$CONTAINER_DIR/tmp/setup.sh"
    cp -r "$MODPATH/setup/servicectl"/* "$CONTAINER_DIR/usr/local/lib/servicectl/"
    chmod 777 "$CONTAINER_DIR/tmp/setup.sh" "$CONTAINER_DIR/usr/local/lib/servicectl/servicectl" "$CONTAINER_DIR/usr/local/lib/servicectl/serviced"

    if ! ruri "$CONTAINER_DIR" /bin/sh /tmp/setup.sh "$LXC_OS" "$PASSWORD" "$PORT"; then
      abort "Failed"
    fi
    ruri -U "$CONTAINER_DIR"

    ui_print "- Automated installation completed!"
    ui_print "- Note: Please change the default password. Exposing an SSH port with password authentication instead of key-based authentication is always a high-risk behavior!"
}

main() {
    bootinspect
    link_busybox

    if [ -z "$ASL" ]; then
        configuration
        automatic
    fi

    inotifyfile
}

main

# set_perm_recursive $MODPATH 0 0 0755 0644
set_perm "$MODPATH/container_ctrl.sh" 0 0 0755

ui_print ""
(sleep 10 && reboot) &
ui_print "The system will restart in 10 seconds..."
