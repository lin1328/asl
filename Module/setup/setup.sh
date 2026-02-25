LXC_OS=$1
PASSWORD=$2
PORT=$3
OS_LIST="alpine archlinux centos debian fedora kali ubuntu"

configure_dns_host() {
    if [ -L /etc/resolv.conf ]; then
        rm -f /etc/resolv.conf
    fi
    cat > /etc/resolv.conf <<-'EOF'
nameserver 1.1.1.1
nameserver 114.114.114.114
nameserver 2606:4700:4700::1111
EOF

    if [ -L /etc/hosts ]; then
        rm -f /etc/hosts
    fi
    cat > /etc/hosts <<-'End'
127.0.0.1 localhost
::1       localhost ip6-localhost ip6-loopback
End
}

create_groups() {
    groupadd -g 1000 aid_system 2>/dev/null || groupadd -g 1074 aid_system 2>/dev/null

    groups="1001 aid_radio
1002 aid_bluetooth
1003 aid_graphics
1004 aid_input
1005 aid_audio
1006 aid_camera
1007 aid_log
1008 aid_compass
1009 aid_mount
1010 aid_wifi
1011 aid_adb
1012 aid_install
1013 aid_media
1014 aid_dhcp
1015 aid_sdcard_rw
1016 aid_vpn
1017 aid_keystore
1018 aid_usb
1019 aid_drm
1020 aid_mdnsr
1021 aid_gps
1023 aid_media_rw
1024 aid_mtp
1026 aid_drmrpc
1027 aid_nfc
1028 aid_sdcard_r
1029 aid_clat
1030 aid_loop_radio
1031 aid_media_drm
1032 aid_package_info
1033 aid_sdcard_pics
1034 aid_sdcard_av
1035 aid_sdcard_all
1036 aid_logd
1037 aid_shared_relro
1038 aid_dbus
1039 aid_tlsdate
1040 aid_media_ex
1041 aid_audioserver
1042 aid_metrics_coll
1043 aid_metricsd
1044 aid_webserv
1045 aid_debuggerd
1046 aid_media_codec
1047 aid_cameraserver
1048 aid_firewall
1049 aid_trunks
1050 aid_nvram
1051 aid_dns
1052 aid_dns_tether
1053 aid_webview_zygote
1054 aid_vehicle_network
1055 aid_media_audio
1056 aid_media_video
1057 aid_media_image
1058 aid_tombstoned
1059 aid_media_obb
1060 aid_ese
1061 aid_ota_update
1062 aid_automotive_evs
1063 aid_lowpan
1064 aid_hsm
1065 aid_reserved_disk
1066 aid_statsd
1067 aid_incidentd
1068 aid_secure_element
1069 aid_lmkd
1070 aid_llkd
1071 aid_iorapd
1072 aid_gpu_service
1073 aid_network_stack
2000 aid_shell
2001 aid_cache
2002 aid_diag
2900 aid_oem_reserved_start
2999 aid_oem_reserved_end
3001 aid_net_bt_admin
3002 aid_net_bt
3003 aid_inet
3004 aid_net_raw
3005 aid_net_admin
3006 aid_net_bw_stats
3007 aid_net_bw_acct
3009 aid_readproc
3010 aid_wakelock
3011 aid_uhid
9997 aid_everybody
9998 aid_misc
9999 aid_nobody
10000 aid_app_start
19999 aid_app_end
20000 aid_cache_gid_start
29999 aid_cache_gid_end
30000 aid_ext_gid_start
39999 aid_ext_gid_end
40000 aid_ext_cache_gid_start
49999 aid_ext_cache_gid_end
50000 aid_shared_gid_start
59999 aid_shared_gid_end
99000 aid_isolated_start
99999 aid_isolated_end
100000 aid_user_offset"

    echo "$groups" | while read gid name; do
        groupadd -g "$gid" "$name" 2>/dev/null
    done
}

add_user_to_groups() {
    user_groups="aid_system,aid_radio,aid_bluetooth,aid_graphics,aid_input,aid_audio,aid_camera,aid_log,aid_compass,aid_mount,aid_wifi,aid_adb,aid_install,aid_media,aid_dhcp,aid_sdcard_rw,aid_vpn,aid_keystore,aid_usb,aid_drm,aid_mdnsr,aid_gps,aid_media_rw,aid_mtp,aid_drmrpc,aid_nfc,aid_sdcard_r,aid_clat,aid_loop_radio,aid_media_drm,aid_package_info,aid_sdcard_pics,aid_sdcard_av,aid_sdcard_all,aid_logd,aid_shared_relro,aid_dbus,aid_tlsdate,aid_media_ex,aid_audioserver,aid_metrics_coll,aid_metricsd,aid_webserv,aid_debuggerd,aid_media_codec,aid_cameraserver,aid_firewall,aid_trunks,aid_nvram,aid_dns,aid_dns_tether,aid_webview_zygote,aid_vehicle_network,aid_media_audio,aid_media_video,aid_media_image,aid_tombstoned,aid_media_obb,aid_ese,aid_ota_update,aid_automotive_evs,aid_lowpan,aid_hsm,aid_reserved_disk,aid_statsd,aid_incidentd,aid_secure_element,aid_lmkd,aid_llkd,aid_iorapd,aid_gpu_service,aid_network_stack,aid_shell,aid_cache,aid_diag,aid_oem_reserved_start,aid_oem_reserved_end,aid_net_bt_admin,aid_net_bt,aid_inet,aid_net_raw,aid_net_admin,aid_net_bw_stats,aid_net_bw_acct,aid_readproc,aid_wakelock,aid_uhid,aid_everybody,aid_misc,aid_nobody,aid_app_start,aid_app_end,aid_cache_gid_start,aid_cache_gid_end,aid_ext_gid_start,aid_ext_gid_end,aid_ext_cache_gid_start,aid_ext_cache_gid_end,aid_shared_gid_start,aid_shared_gid_end,aid_isolated_start,aid_isolated_end,aid_user_offset"
    usermod -a -G "$user_groups" root 2>/dev/null
    usermod -g aid_inet _apt 2>/dev/null
}

servicectl_links() {
    if [ -d /usr/local/lib/servicectl ]; then
        ln -sf /usr/local/lib/servicectl/serviced /usr/bin/serviced
        ln -sf /usr/local/lib/servicectl/servicectl /usr/bin/servicectl
    fi
}

fix_sudo_permissions() {
    # for dir in /etc /run /var/lib /var/log; do
    #     if [ -d "$dir" ]; then
    #         sudo chown -R root:root "$dir"
    #         sudo chmod 755 "$dir"
    #     fi
    # done

    if [ -f /etc/sudoers ]; then
        chown root:root /etc/sudoers
        chmod 440 /etc/sudoers
    fi

    if [ -f /etc/sudo.conf ]; then
        chown root:root /etc/sudo.conf
        chmod 644 /etc/sudo.conf
    fi

    if [ -d /etc/sudoers.d ]; then
        chown root:root /etc/sudoers.d
        chmod 755 /etc/sudoers.d

        find /etc/sudoers.d -type f -exec chown root:root {} \;
        find /etc/sudoers.d -type f -exec chmod 440 {} \;

        find /etc/sudoers.d -type d -exec chown root:root {} \;
        find /etc/sudoers.d -type d -exec chmod 755 {} \;
    fi

    if [ -d /usr/libexec/sudo ]; then
        chown -R root:root /usr/libexec/sudo
        chmod -R 755 /usr/libexec/sudo

        if [ -f /usr/libexec/sudo/sudoers.so ]; then
            chown root:root /usr/libexec/sudo/sudoers.so
            chmod 644 /usr/libexec/sudo/sudoers.so
        fi
    fi
}

add_user_with_sudo() {
    local username="$1"

    if id "$username" >/dev/null 2>&1; then
        userdel -r "$username" 2>/dev/null
        # userdel -r --force "$username"
        if [ -d "/home/$username" ]; then
            rm -rf "/home/$username"
        fi
    fi

    if command -v bash >/dev/null 2>&1; then
        useradd -m -s /bin/bash "$username"
    else
        useradd -m "$username"
    fi

    echo "$username:$username" | chpasswd

    if grep -q "^%sudo" /etc/sudoers; then
        usermod -aG sudo "$username"
        echo "$username ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    elif grep -q "^%wheel" /etc/sudoers; then
        usermod -aG wheel "$username"
        echo "$username ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    else
        echo "$username ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    fi

    chown "$username:$username" "/home/$username"
    chmod 700 "/home/$username"
}

setup_archlinux() {
    # Disable CheckSpace (optional, use with caution is recommended)
    sed -i "/^CheckSpace/s/^/#/" /etc/pacman.conf
    if ! grep -q "^IgnorePkg = linux-aarch64 linux-firmware" /etc/pacman.conf; then
        sed -i "/^#IgnorePkg/a\\IgnorePkg = linux-aarch64 linux-firmware" /etc/pacman.conf
    fi

    cat > /etc/pacman.d/mirrorlist <<-'EndOfArchMirrors'
# Arch Linux ARM mirrorlist
Server = http://mirror.archlinuxarm.org/$arch/$repo
Server = https://mirrors.ustc.edu.cn/archlinuxarm/$arch/$repo
# Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxarm/$arch/$repo
# Server = https://mirrors.bfsu.edu.cn/archlinuxarm/$arch/$repo
EndOfArchMirrors

    cat > /etc/pacman.conf <<-'Endofpacman'
[options]
Architecture = aarch64
LocalFileSigLevel = Optional
ParallelDownloads = 5
RemoteFileSigLevel = Optional
SigLevel = Required DatabaseOptional

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[community]
Include = /etc/pacman.d/mirrorlist

[alarm]
Include = /etc/pacman.d/mirrorlist

[arch4edu]
Server = https://mirrors.bfsu.edu.cn/arch4edu/$arch
Server = https://mirrors.tuna.tsinghua.edu.cn/arch4edu/$arch
Server = https://mirror.lesviallon.fr/arch4edu/$arch
SigLevel = Never

[archlinuxcn]
Server = https://mirrors.bfsu.edu.cn/archlinuxcn/$arch
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/$arch
Server = https://repo.archlinuxcn.org/$arch
SigLevel = Never
Endofpacman

    if [ ! -d /etc/pacman.d/gnupg ]; then
        pacman-key --init
        pacman-key --populate archlinux archlinuxarm
    fi


    # Force update the database and install the keyring (use --overwrite to avoid file conflicts)
    # pacman -Syy --noconfirm --needed --overwrite='*' archlinux-keyring archlinuxarm-keyring
    pacman -Sy --noconfirm --needed archlinux-keyring archlinuxarm-keyring

    # Force or safely remove the kernel and firmware packages (if needed)
    # pacman -Rdd --noconfirm linux-aarch64 linux-firmware 2>/dev/null || true
    # pacman -Rs --noconfirm linux-aarch64 linux-firmware
    # pacman -S --force filesystem

    pacman -Syu --noconfirm --needed openssh

    servicectl_links

    ssh-keygen -A

    # When packaging a software package (such as an AUR package) using `makepkg`, you may encounter an issue where the system cannot enter the fakeroot environment because it is not started by systemd and does not have SYSV pipes and message queues
    # To resolve this issue, download the appropriate `fakeroot-tcp` for your system =>>https://pkgs.org/download/fakeroot-tcp
    # pacman -S --overwrite '*' yay     # It is necessary to compile `archlinuxcn-keyring` by yourself

    fix_sudo_permissions
    add_user_with_sudo "$LXC_OS"
}

setup_alpine() {
    apk update
    apk add openrc openssh sudo shadow

    mkdir -p /run/openrc
    touch /run/openrc/softlevel
    openrc

    rc-service devfs start

    rc-update add sshd
    # rc-update add resolvconf default

    fix_sudo_permissions
    add_user_with_sudo "$LXC_OS"
}

setup_centos() {
    yum update -y
    yum install -y openssh-server sudo
    yum clean all

    servicectl_links

    ssh-keygen -A

    fix_sudo_permissions
    add_user_with_sudo "$LXC_OS"
}

setup_debian() {
    apt-get update
    apt-get install -y openssh-server sudo
    apt-get autoclean

    fix_sudo_permissions
    add_user_with_sudo "$LXC_OS"
}

setup_fedora() {
    dnf update -y
    dnf install -y openssh-server sudo
    dnf clean all

    servicectl_links

    ssh-keygen -A

    fix_sudo_permissions
    add_user_with_sudo "$LXC_OS"
}

setup_kali() {
    apt-get update
    apt-get install -y openssh-server sudo
    apt-get autoclean

    fix_sudo_permissions
    add_user_with_sudo "$LXC_OS"

    # apt-get install kali-tools-top10
    # apt-get install kali-linux-all
}

configure_ssh() {
    local port=${PORT:-22}

    if [ ! -f /etc/ssh/sshd_config ]; then
        echo "File sshd_config does not exist"
        return 1
    fi

    if grep -Eq "^#?\s*PermitRootLogin" /etc/ssh/sshd_config; then
        sed -i 's/^#\?\s*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    else
        echo "PermitRootLogin no" >> /etc/ssh/sshd_config
    fi

    if grep -Eq "^#?\s*PasswordAuthentication\s" /etc/ssh/sshd_config; then
        sed -i 's/^#\?\s*PasswordAuthentication\s.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    else
        echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
    fi

    if grep -Eq "^#?\s*Port" /etc/ssh/sshd_config; then
        sed -i "s/^#\?\s*Port .*/Port ${port}/" /etc/ssh/sshd_config
    else
        echo "Port ${port}" >> /etc/ssh/sshd_config
    fi

    # Close PAM certification (optional)
    if grep -Eq "^#?\s*UsePAM" /etc/ssh/sshd_config; then
        sed -i 's/^#\?\s*UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config
    else
        echo "UsePAM yes" >> /etc/ssh/sshd_config
    fi

    if grep -Eq "^#?\s*PermitTTY" /etc/ssh/sshd_config; then
        sed -i '0,/^#\?\s*PermitTTY/s/^#\?\s*PermitTTY.*/PermitTTY yes/' /etc/ssh/sshd_config
    else
        echo "PermitTTY yes" >> /etc/ssh/sshd_config
    fi

    # Allow specified users (optional)
    # echo "AllowUsers user1 user2" >> /etc/ssh/sshd_config

    # systemctl restart sshd || service ssh restart
}

main() {
    local valid=0

    for os in $OS_LIST; do
        if [ "$LXC_OS" = "$os" ]; then
            valid=1
            break
        fi
    done

    if [ "$valid" -eq 0 ]; then
        echo "Unsupported LXC operating system '$LXC_OS'"
        return 1
    fi

    if [ -n "$PORT" ]; then
        case $PORT in
            *[!0-9]*) 
                echo "PORT must be a number" >&2
                return 1
                ;;
        esac
        
        if [ ${#PORT} -lt 2 ]; then
            echo "PORT must be at least two digits" >&2
            return 1
        fi
        
        if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
            echo "PORT must be between 1 and 65535" >&2
            return 1
        fi
    fi

    configure_dns_host
    create_groups
    add_user_to_groups
    echo "root:${PASSWORD:-J@#KmMr0@10%&x?j}" | chpasswd

    case "$LXC_OS" in
    archlinux) setup_archlinux ;;
    alpine) setup_alpine ;;
    centos) setup_centos ;;
    debian|ubuntu) setup_debian ;;
    fedora) setup_fedora ;;
    kali) setup_kali ;;
    esac

    configure_ssh
}

main

exit $?
