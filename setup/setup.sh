LXC_OS=$1
PASSWORD=$2
PORT=$3

configure_dns_host() {
    # 部分系统是一个软链接无法写入 只能删除后才能写入
    if [ -L /etc/resolv.conf ]; then
        rm -f /etc/resolv.conf
    fi
    touch /etc/resolv.conf
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
    echo "nameserver 114.114.114.114" >> /etc/resolv.conf
    echo "nameserver 2606:4700:4700::1111" >> /etc/resolv.conf

    if [ -L /etc/hosts ]; then
        rm -f /etc/hosts
    fi
    touch /etc/hosts
    echo "127.0.0.1 localhost" > /etc/hosts
    echo "::1       localhost ip6-localhost ip6-loopback" >> /etc/hosts
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

setup_archlinux() {
    sed -i "/^CheckSpace/s/^/#/" /etc/pacman.conf
    sed -i "/^#IgnorePkg/a\\IgnorePkg = linux-aarch64 linux-firmware" /etc/pacman.conf

    # sed -i.bak 's|http://mirror.archlinuxarm.org|https://mirrors.ustc.edu.cn/archlinuxarm|g' /etc/pacman.d/mirrorlist

    cat > /etc/pacman.d/mirrorlist <<-'EndOfArchMirrors'
# Archlinux arm
# Server = http://mirror.archlinuxarm.org/$arch/$repo
Server = https://mirrors.ustc.edu.cn/archlinuxarm/$arch/$repo
# Server = https://mirrors.bfsu.edu.cn/archlinuxarm/$arch/$repo
# Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxarm/$arch/$repo
# Server = https://mirrors.163.com/archlinuxarm/$arch/$repo
EndOfArchMirrors

    cat >>/etc/pacman.conf <<-'Endofpacman1'
[arch4edu]
Server = https://mirrors.bfsu.edu.cn/arch4edu/$arch
Server = https://mirrors.tuna.tsinghua.edu.cn/arch4edu/$arch
Server = https://mirror.autisten.club/arch4edu/$arch
Server = https://arch4edu.keybase.pub/$arch
Server = https://mirror.lesviallon.fr/arch4edu/$arch
Server = https://mirrors.tencent.com/arch4edu/$arch
SigLevel = Never
Endofpacman1

    cat >>/etc/pacman.conf <<-'Endofpacman2'
[archlinuxcn]
Server = https://mirrors.bfsu.edu.cn/archlinuxcn/$arch
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/$arch
Server = https://repo.archlinuxcn.org/$arch
SigLevel = Never
Endofpacman2

    pacman-key --init
    pacman-key --populate archlinuxarm
    pacman -Sy --noconfirm archlinux-keyring archlinuxarm-keyring

    pacman -Rs linux-aarch64 linux-firmware --noconfirm

    pacman -Syu --noconfirm
    pacman -Sy --noconfirm --needed openssh

    ln -s /usr/local/lib/servicectl/serviced /usr/bin/serviced
    ln -s /usr/local/lib/servicectl/servicectl /usr/bin/servicectl

    ssh-keygen -A

    # 当通过 makepkg 打包一个软件包（比如说 AUR 包）时，会因为这个系统不是由 systemd 启动，没有 SYSV 管道和消息队列而无法进入 fakeroot 环境 附解决方案 根据你的系统下载相应的 fakeroot-tcp 来解决这个问题 =>>https://pkgs.org/download/fakeroot-tcp
    # pacman -S --overwrite '*' yay     # 需要自行编译  archlinuxcn-keyring
}

setup_alpine() {
    # sed -i.bak 's|http://dl-cdn.alpinelinux.org/alpine|https://mirrors.ustc.edu.cn/alpine|g' /etc/apk/repositories

    apk update
    apk add openrc openssh

    mkdir -p /run/openrc
    touch /run/openrc/softlevel
    openrc

    rc-service devfs start
    rc-service dmesg start

    rc-update add sshd
    rc-update add resolvconf default
}

setup_centos() {
    # sed -i.bak 's|^mirrorlist=|#mirrorlist=|g; s|^#baseurl=http://mirror.centos.org|baseurl=https://mirrors.ustc.edu.cn|g' /etc/yum.repos.d/CentOS-*.repo

    yum update -y
    yum install -y openssh-server
    yum clean all

    ln -s /usr/local/lib/servicectl/serviced /usr/bin/serviced
    ln -s /usr/local/lib/servicectl/servicectl /usr/bin/servicectl

    ssh-keygen -A
}

setup_debian() {
    # sed -i.bak "s|http://deb.debian.org|https://mirrors.ustc.edu.cn|g; s|http://security.debian.org|https://mirrors.ustc.edu.cn/debian-security|g" /etc/apt/sources.list

    apt update
    apt install -y openssh-server
    apt autoclean
}

setup_fedora() {
    # sed -i.bak 's|^metalink=|#metalink=|g; s|^#baseurl=http://download.fedoraproject.org/pub|baseurl=https://mirrors.ustc.edu.cn|g' /etc/yum.repos.d/fedora*.repo

    dnf update -y
    dnf install -y openssh-server
    dnf clean all

    ln -s /usr/local/lib/servicectl/serviced /usr/bin/serviced
    ln -s /usr/local/lib/servicectl/servicectl /usr/bin/servicectl

    ssh-keygen -A
}

setup_kali() {
    # sed -i.bak "s|http://http.kali.org/kali|https://mirrors.ustc.edu.cn/kali|g" /etc/apt/sources.list

    apt update
    apt install -y openssh-server
    apt autoclean

    # 可选工具安装
    # apt install kali-tools-top10
    # apt install kali-linux-all
}

setup_ubuntu() {
    # sed -i.bak "s|http://archive.ubuntu.com|https://mirrors.ustc.edu.cn|g; s|http://security.ubuntu.com|https://mirrors.ustc.edu.cn|g" /etc/apt/sources.list

    apt update
    apt install -y openssh-server
    apt autoclean
}

# fedora http://download.example
# ubuntu http://ports.ubuntu.com
# 不确保所有源都与脚本一致 只是作一个示例 请根据实际情况按需修改

configure() {
    local port=${PORT:-22}

    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

    if grep -Eq "^#?\s*PermitRootLogin" /etc/ssh/sshd_config; then
        sed -i 's/^#\?\s*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    else
        echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
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

    if grep -Eq "^#?\s*UsePAM" /etc/ssh/sshd_config; then
        sed -i 's/^#\?\s*UsePAM.*/UsePAM no/' /etc/ssh/sshd_config
    else
        echo "UsePAM no" >> /etc/ssh/sshd_config
    fi

    # sed -i '/^#.*%wheel ALL=(ALL) ALL/ s/^#//' /etc/sudoers

    # archlinux
    # sed -i 's/exit $E_ROOT/#exit $E_ROOT/' /usr/bin/makepkg
    # sed -i 's/^#XferCommand = \/usr\/bin\/curl -L -C - -f -o %o %u/XferCommand = \/usr\/bin\/curl -L -C - -f -o %o %u/' /etc/pacman.conf

    # 创建ssh服务的软链接，安卓上似乎有问题，但貌似不用创建也可以
    # ln -s /usr/lib/systemd/system/sshd.service /usr/local/lib/servicectl/enabled/sshd.service
    # if grep -q "java" /usr/local/lib/servicectl/enabled/sshd.service; then
    #     rm -f /usr/local/lib/servicectl/enabled/sshd.service
    #     echo "/usr/lib/systemd/system/sshd.service" > /usr/local/lib/servicectl/enabled/sshd.service
    #     # cat /usr/lib/systemd/system/sshd.service > /usr/local/lib/servicectl/enabled/sshd.service
    # fi
}

main() {
    configure_dns_host

    create_groups

    add_user_to_groups

    echo "root:${PASSWORD:-123456}" | chpasswd

    case "$LXC_OS" in
        archlinux) setup_archlinux ;;
        alpine) setup_alpine ;;
        centos) setup_centos ;;
        debian) setup_debian ;;
        fedora) setup_fedora ;;
        kali) setup_kali ;;
        ubuntu) setup_ubuntu ;;
        *)
            echo "不支持的 LXC 操作系统：$LXC_OS"
            exit 1
            ;;
    esac

    configure
}

main
