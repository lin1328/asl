#!/data/data/com.termux/files/usr/bin/bash

TERMUX_PATH="/data/data/com.termux/files/usr"
export PATH="$TERMUX_PATH/bin:$PATH"

if [ "$(id -u)" != "0" ]; then
    exec su -c "PATH=$PATH $0 $*"
fi

MODULEID="asl_dev"
BASE_DIR="/data/lxc"
BACKUP_DIR="/data/lxc"
OS_LIST=("ubuntu" "debian" "archlinux" "alpine" "centos" "fedora" "kali")

echoRgb() {
    local message="$1"
    local color_code="${2:-6}"

    case "$color_code" in
        1) color="\033[0;31m" ;;
        2) color="\033[0;32m" ;;
        3) color="\033[0;33m" ;;
        4) color="\033[0;34m" ;;
        5) color="\033[0;35m" ;;
        6) color="\033[0;36m" ;;
        7) color="\033[0;37m" ;;
        *) color="\033[0m"    ;;
    esac

    printf "%b%s\033[0m\n" "$color" "$message"
}

abort() {
    echo -e "\e[1;31m $@ \e[0m"
    sleep 1
    rm -f $(readlink -f "$0")
    exit 0
}

echo
echo "Welcome to Termux"
echoRgb "欢迎使用 Android Subsystem for GNU/Linux" 4

for cmd in curl wget rsync; do
    command -v "$cmd" >/dev/null 2>&1 || abort "! 依赖的命令 $cmd 未安装" 
done

echoRgb "请在15秒内按任意键继续..." 3

if ! read -t 15 -n 1 input; then
    abort "! 未输入任意按键"
fi
echo

pause_func() {
    read -p "按回车键继续..." pause
}

check_installed_systems() {
    local found=0

    echo "正在检查已安装的系统..."
    echo "═══════════════════════════════════"

    for os in "${OS_LIST[@]}"; do
        local sys_path="$BASE_DIR/$os"
        if [ -d "$sys_path" ]; then
            found=1
            echo "发现系统: $os"

            local size=$(du -sh "$sys_path" | cut -f1)

            if [ -f "$sys_path/etc/os-release" ]; then
                local name=$(grep "^NAME=" "$sys_path/etc/os-release" | cut -d'"' -f2)
                local version=$(grep "^VERSION=" "$sys_path/etc/os-release" | cut -d'"' -f2)

                echo "├─ 系统名称: $name"
                [ ! -z "$version" ] && echo "├─ 版本信息: $version"
                echo "├─ 安装位置: $sys_path"
                echo "└─ 占用空间: $size"

                case $os in
                    "ubuntu")
                        if [ -f "$sys_path/etc/lsb-release" ]; then
                            echo "   └─ Ubuntu 版本: $(grep "DISTRIB_RELEASE" "$sys_path/etc/lsb-release" | cut -d'=' -f2)"
                        fi
                        ;;
                    "debian")
                        if [ -f "$sys_path/etc/debian_version" ]; then
                            echo "   └─ Debian 版本: $(cat "$sys_path/etc/debian_version")"
                        fi
                        ;;
                    "archlinux")
                        if [ -f "$sys_path/etc/arch-release" ]; then
                            echo "   └─ Arch Linux 版本: $(cat "$sys_path/etc/arch-release")"
                        fi
                        ;;
                    "alpine")
                        if [ -f "$sys_path/etc/alpine-release" ]; then
                            echo "   └─ Alpine 版本: $(cat "$sys_path/etc/alpine-release")"
                        fi
                        ;;
                    "centos")
                        if [ -f "$sys_path/etc/centos-release" ]; then
                            echo "   └─ CentOS 版本: $(cat "$sys_path/etc/centos-release")"
                        fi
                        ;;
                esac
            else
                echo "├─ 安装位置: $sys_path"
                echo "└─ 占用空间: $size"
            fi
            echo "───────────────────────────────"
        fi
    done

    if [ $found -eq 0 ]; then
        echo "未找到任何已安装的系统"
        echo "当前支持的系统列表: "
        for os in "${OS_LIST[@]}"; do
            echo "- $os"
        done
        return 1
    fi

    return 0
}

check_os_versions() {
    local os_name="$1"
    local mirror_choice="$2"

    declare -A MIRRORS=(
        ["default"]="https://images.linuxcontainers.org"
        ["tuna"]="https://mirrors.tuna.tsinghua.edu.cn/lxc-images"
        ["ustc"]="https://mirrors.ustc.edu.cn/lxc-images"
        ["sjtu"]="https://mirrors.sjtug.sjtu.edu.cn/lxc-images"
    )

    if [ -z "$mirror_choice" ] || [ -z "${MIRRORS[$mirror_choice]}" ]; then
        mirror_choice="default"
    fi

    local base_url="${MIRRORS[$mirror_choice]}"
    local api_url="$base_url/meta/1.0/index-system"

    if [ -z "$os_name" ]; then
        echo "请指定系统名称"
        echo "支持的系统: ${OS_LIST[@]}"
        echo "支持的镜像源: ${!MIRRORS[@]}"
        return
    fi

    local is_supported=0
    for os in "${OS_LIST[@]}"; do
        if [ "$os" = "$os_name" ]; then
            is_supported=1
            break
        fi
    done

    if [ $is_supported -eq 0 ]; then
        echo "不支持的系统: $os_name"
        echo "支持的系统: ${OS_LIST[@]}"
        return
    fi

    echo "使用镜像源: $mirror_choice ($base_url)"
    echo "正在获取 $os_name 的可用版本..."
    echo "是否显示完整信息? (直接回车或输入 y 显示完整信息)"
    echo "═══════════════════════════════════"

    read -t 10 -r show_full
    show_full=${show_full:-y}

    local versions_found_file=$(mktemp)
    echo 0 > "$versions_found_file"

    if ! curl -s "$api_url" | grep "^$os_name;" | while IFS=';' read -r distro version arch variant date path; do
        if [ "$arch" = "arm64" ] && [ "$variant" = "default" ]; then
            echo 1 > "$versions_found_file"

            if [[ "$show_full" =~ ^[yY]?$ ]]; then
                echo "版本: $version"
                echo "├─ 架构: $arch"
                echo "├─ 变体: $variant"
                echo "├─ 日期: $date"
                echo "└─ 路径: $path"
                echo "───────────────────────────────"
            else
                echo "版本: $version"
            fi
        fi
    done; then
        echo "获取版本信息失败 请检查网络连接或尝试其他镜像源"
    fi

    if [ "$(cat "$versions_found_file")" -eq 0 ]; then
        echo "未找到 $os_name 的 ARM64 架构版本"
    fi

    rm -f "$versions_found_file"
}

check_backup_status() {
    local os_name="$1"
    local max_backups=3
    local min_backup_size=10240

    local backup_files=()
    backup_files+=("$BACKUP_DIR/$os_name.old.tar.gz")
    for i in $(seq 1 $((max_backups - 1))); do
        backup_files+=("$BACKUP_DIR/$os_name.old.$i.tar.gz")
    done

    local backup_count=0
    local total_backup_size=0
    local latest_backup=""
    local small_backups=0

    echo "========== $os_name 备份状态 =========="

    for file in "${backup_files[@]}"; do
        if [ -f "$file" ]; then
            local size=$(stat -c "%s" "$file" 2>/dev/null)
            local human_size=$(numfmt --to=iec-i --suffix=B "$size" 2>/dev/null)
            local mtime=$(stat -c "%y" "$file" 2>/dev/null | cut -d' ' -f1)

            echo "$((backup_count + 1)). 备份 $((backup_count + 1))"
            echo "   位置: $file"
            echo "   大小: $human_size"
            echo "   创建时间: $mtime"

            if [ -n "$size" ] && [ "$size" -lt "$min_backup_size" ] 2>/dev/null; then
                echo "   [警告] 备份大小异常 可能不完整"
                ((small_backups++))
            fi

            ((backup_count++))
            total_backup_size=$((total_backup_size + size))

            if [ -z "$latest_backup" ]; then
                latest_backup="$file"
            fi
        fi
    done

    echo "----------------------------"
    echo "备份总数: $backup_count"
    echo "总备份大小: $(numfmt --to=iec-i --suffix=B $total_backup_size)"

    if [ $backup_count -eq 0 ]; then
        echo "未找到任何备份"
        read -p "是否创建初始备份? (y/N): " create_backup

        if [[ "$create_backup" =~ ^[Yy]$ ]]; then
            create_initial_backup "$os_name"
            backup_count=1
        fi
    elif [ $small_backups -gt 0 ]; then
        echo "警告: 发现 $small_backups 个异常小的备份"
        read -p "是否重新创建备份? (y/N): " recreate_backup

        if [[ "$recreate_backup" =~ ^[Yy]$ ]]; then
            create_initial_backup "$os_name"
            backup_count=1
        fi
    fi

    return $backup_count
}

create_initial_backup() {
    local os_name="$1"
    local current_backup="$BACKUP_DIR/$os_name.old.tar.gz"
    local source_path="$BASE_DIR/$os_name"

    if [ ! -d "$source_path" ]; then
        echo "源系统目录 $source_path 不存在"
        return 1
    fi

    echo "正在创建 $os_name 的初始备份..."
    if tar -czf "$current_backup" -C "$source_path" . 2>/dev/null; then
        echo "备份创建成功"

        local backup_size=$(stat -c "%s" "$current_backup" 2>/dev/null)
        if [ "$backup_size" -lt 10240 ]; then
            echo "警告: 备份大小异常（$backup_size 字节）"
            read -p "是否重试备份? (y/N): " retry
            if [[ "$retry" =~ ^[Yy]$ ]]; then
                rm -f "$current_backup"
                create_initial_backup "$os_name"
            else
                return 1
            fi
        fi

        return 0
    else
        echo "备份创建失败"
        rm -f "$current_backup"
        return 1
    fi
}

create_new_backup() {
    local os_name="$1"
    local source_dir="$BASE_DIR/$os_name"
    local current_backup="$BACKUP_DIR/$os_name.old.tar.gz"
    local max_backups=3

    if [ ! -f "$current_backup" ]; then
        echo "当前备份不存在 尝试创建初始备份"
        create_initial_backup "$os_name"
        return $?
    fi

    local backup_files=()
    backup_files+=("$current_backup")
    for i in $(seq 1 $((max_backups - 1))); do
        backup_files+=("$BACKUP_DIR/$os_name.old.$i.tar.gz")
    done

    local backup_count=0
    for file in "${backup_files[@]}"; do
        if [ -f "$file" ]; then
            ((backup_count++))
        fi
    done

    if [ $backup_count -lt $max_backups ]; then
        for ((i=backup_count; i>0; i--)); do
            local src="${backup_files[$((i-1))]}"
            local dest="${backup_files[i]}"

            if [ -f "$src" ]; then
                echo "移动备份: $src → $dest"
                mv "$src" "$dest"
            fi
        done

        echo "正在创建新备份..."
        if tar -czvf "${backup_files[0]}" -C "$source_dir" . 2>/dev/null; then
            echo "备份创建完成"
            return 0
        else
            echo "备份创建失败"
            rm -f "${backup_files[0]}"
            return 1
        fi
    else
        echo "已达到最大备份数量"
        return 1
    fi
}

view_backup_details() {
    local os_name="$1"
    local max_backups=3

    local backup_files=()
    backup_files+=("$BACKUP_DIR/$os_name.old.tar.gz")
    for i in $(seq 1 $((max_backups - 1))); do
        backup_files+=("$BACKUP_DIR/$os_name.old.$i.tar.gz")
    done

    local backup_count=0
    local available_backups=()
    
    for file in "${backup_files[@]}"; do
        if [ -f "$file" ]; then
            available_backups+=("$file")
            ((backup_count++))
        fi
    done

    if [ $backup_count -eq 0 ]; then
        echo "没有备份可查看"
        return 1
    fi

    echo "可用备份: "
    for ((i=0; i<${#available_backups[@]}; i++)); do
        echo "$((i+1)). ${available_backups[i]}"
    done

    read -p "选择要查看的备份 (1-$backup_count): " detail_choice

    if [[ "$detail_choice" -ge 1 && "$detail_choice" -le $backup_count ]]; then
        local detail_file="${available_backups[$((detail_choice-1))]}"

        echo "备份详情: $detail_file"
        echo "----------------------------"

        local backup_size=$(stat -c "%s" "$detail_file" 2>/dev/null)
        local human_size=$(numfmt --to=iec-i --suffix=B "$backup_size" 2>/dev/null)
        echo "总大小: ${human_size:-未知}"

        local file_count=$(tar -tzf "$detail_file" 2>/dev/null | wc -l)
        echo "文件数量: $file_count"

        local backup_time=$(stat -c "%y" "$detail_file" 2>/dev/null | cut -d' ' -f1)
        echo "最后修改时间: ${backup_time:-未知}"

        echo "----------------------------"
        echo "前10个文件: "
        tar -tzf "$detail_file" 2>/dev/null | head -n 10 || echo "无法列出文件"

        return 0
    else
        echo "无效的选择"
        return 1
    fi
}

backup_menu() {
    local os_name="$1"

    while true; do
        clear
        echo "========== 备份管理 - $os_name =========="
        
        check_backup_status "$os_name"
        local backup_count=$?

        echo "操作选项: "
        if [ $backup_count -lt 3 ]; then
            echo "1. 创建新备份"
        fi
        if [ $backup_count -gt 0 ]; then
            echo "2. 还原备份"
            echo "3. 删除最旧备份"
            echo "4. 查看备份详情"
        fi
        echo "0. 返回上级菜单"
        echo "========================================="

        read -p "请选择操作 [0-4]: " choice

        case $choice in
            1)
                create_new_backup "$os_name"
                ;;
            2)
                restore_backup "$os_name"
                ;;
            3)
                delete_oldest_backup "$os_name"
                ;;
            4)
                view_backup_details "$os_name"
                ;;
            0)
                return 0
                ;;
            *)
                echo "无效的选择"
                ;;
        esac

        pause_func
    done
}

system_backup_menu() {
    while true; do
        clear
        echo "========== 系统备份管理 =========="

        local available_systems=()
        local system_dirs=()
        
        for file in "$BACKUP_DIR"/*.old.tar.gz; do
            if [ -f "$file" ]; then
                local system_name=$(basename "$file" .old.tar.gz)
                available_systems+=("$system_name (已备份)")
                system_dirs+=("$file")
            fi
        done

        for os in "${OS_LIST[@]}"; do
            local sys_path="$BASE_DIR/$os"
            if [ -d "$sys_path" ] && [ ! -f "$BACKUP_DIR/$os.old.tar.gz" ]; then
                available_systems+=("$os (未备份)")
                system_dirs+=("$sys_path")
            fi
        done

        if [ ${#available_systems[@]} -eq 0 ]; then
            echo "未找到任何系统"
            read -p "按回车键返回..." pause
            return 0
        fi

        for ((i=0; i<${#available_systems[@]}; i++)); do
            echo "$((i+1)). ${available_systems[i]}"
        done

        echo "0. 返回上级菜单"
        echo "======================================"

        read -p "请选择系统 [0-${#available_systems[@]}]: " sys_choice

        if [ "$sys_choice" -eq 0 ] 2>/dev/null; then
            return 0
        fi

        if [[ "$sys_choice" -gt 0 && "$sys_choice" -le ${#available_systems[@]} ]]; then
            local selected_system=$(echo "${available_systems[$((sys_choice-1))]}" | awk '{print $1}')
            local selected_path="${system_dirs[$((sys_choice-1))]}"

            if [[ "${available_systems[$((sys_choice-1))]}" == *"未备份"* ]]; then
                read -p "系统 $selected_system 尚未备份 是否立即创建备份? (y/N): " create_backup

                if [[ "$create_backup" =~ ^[Yy]$ ]]; then
                    
                    echo "正在创建 $selected_system 的初始备份..."
                    if tar -czf "$BACKUP_DIR/$selected_system.old.tar.gz" "$BASE_DIR/$selected_system" . 2>/dev/null; then
                        backup_menu "$selected_system"
                    else
                        echo "备份创建失败"
                        rm -f "$BACKUP_DIR/$selected_system.old.tar.gz"
                        pause_func
                    fi
                fi
            else
                backup_menu "$selected_system"
            fi
        else
            echo "无效的选择"
            pause_func
        fi
    done
}

delete_oldest_backup() {
    local os_name="$1"
    local max_backups=3

    local backup_files=()
    backup_files+=("$BACKUP_DIR/$os_name.old.tar.gz")
    for i in $(seq 1 $((max_backups - 1))); do
        backup_files+=("$BACKUP_DIR/$os_name.old.$i.tar.gz")
    done

    local backup_count=0
    local available_backups=()
    
    for file in "${backup_files[@]}"; do
        if [ -f "$file" ]; then
            available_backups+=("$file")
            ((backup_count++))
        fi
    done

    if [ $backup_count -eq 0 ]; then
        echo "没有可删除的备份"
        return 1
    fi

    local oldest_backup="${available_backups[$((backup_count-1))]}"

    read -p "确认删除最旧备份 $oldest_backup? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "删除备份: $oldest_backup"
        rm -f "$oldest_backup"
        echo "备份删除成功"
        return 0
    else
        echo "操作取消"
        return 1
    fi
}

restore_backup() {
    local os_name="$1"
    local current_backup="$BACKUP_DIR/$os_name.old.tar.gz"
    local max_backups=3
    local source_path="$BASE_DIR/$os_name"

    local backup_files=()
    backup_files+=("$BACKUP_DIR/$os_name.old.tar.gz")
    for i in $(seq 1 $((max_backups - 1))); do
        backup_files+=("$BACKUP_DIR/$os_name.old.$i.tar.gz")
    done

    local backup_count=0
    local available_backups=()

    for file in "${backup_files[@]}"; do
        if [ -f "$file" ]; then
            available_backups+=("$file")
            ((backup_count++))
        fi
    done

    if [ $backup_count -eq 0 ]; then
        echo "没有可还原的备份"
        return 1
    fi

    echo "可用备份: "
    for ((i=0; i<${#available_backups[@]}; i++)); do
        echo "$((i+1)). ${available_backups[i]}"
    done
    echo "$((backup_count+1)). 从自定义文件还原"

    read -p "选择要还原的备份 (1-$((backup_count+1))): " restore_choice

    if [[ "$restore_choice" -ge 1 && "$restore_choice" -le $((backup_count+1)) ]]; then
        local restore_file=""
        if [[ "$restore_choice" -le $backup_count ]]; then
            restore_file="${available_backups[$((restore_choice-1))]}"
        else
            read -p "请输入自定义备份文件路径（必须以/开头）: " custom_restore_file

            if [[ ! "$custom_restore_file" =~ ^/ ]] || [ ! -f "$custom_restore_file" ]; then
                echo "路径必须以 / 开头或文件不存在"
                return 1
            fi

            if ! tar -tzf "$custom_restore_file" &>/dev/null | grep -q "./usr/lib/os-release"; then
                echo "未检测到有效的系统备份文件"
                return 1
            fi

            restore_file="$custom_restore_file"
        fi

        echo "还原选项: "
        echo "1. 还原到新的目录"
        echo "2. 还原到源系统目录 ($source_path)"
        read -p "请选择还原选项 (1-2): " restore_option

        case "$restore_option" in
            1)
                read -p "请输入新的还原目录路径（必须以/开头）: " new_restore_dir
                if [[ ! "$new_restore_dir" =~ ^/ ]] || [ "$new_restore_dir" == "/" ]; then
                    echo "不能使用根目录"
                    return 1
                fi

                if [[ "$(ls -A "$new_restore_dir")" =~ [^[:space:]] ]]; then
                    echo "目录 '$new_restore_dir' 不为空，请注意备份现有数据。"
                    read -p "是否仍然使用此目录进行还原? (y/n): " confirm
                    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
                        echo "还原操作已取消。"
                        return 1
                    fi
                fi

                echo "正在还原到新的目录 $new_restore_dir..."
                mkdir -p "$new_restore_dir"
                if tar -xzf "$restore_file" -C "$new_restore_dir" 2>/dev/null; then
                    echo "还原完成"
                else
                    echo "还原失败"
                fi
                ;;
            2)
                read -p "警告：此操作会覆盖源系统目录，确定要继续吗? (y/N): " confirm_overwrite
                if [[ "$confirm_overwrite" =~ ^[Yy]$ ]]; then
                    echo "正在还原到源系统目录..."
                    rm -rf "$source_path/*" 2>/dev/null
                    if tar -xzf "$restore_file" -C "$source_path" 2>/dev/null; then
                        echo "还原完成"
                    else
                        echo "还原失败"
                    fi
                else
                    echo "操作取消"
                fi
                ;;
            *)
                echo "无效的选择"
                return 1
                ;;
        esac
        return 0
    else
        echo "无效的选择"
        return 1
    fi
}

download_system_image() {
    local os_name="$1"
    local mirror_choice="${2:-default}"
    local target_dir="$BASE_DIR/$os_name"
    local version="${3:-default}"

    declare -A MIRRORS=(
        ["default"]="https://images.linuxcontainers.org"
        ["tuna"]="https://mirrors.tuna.tsinghua.edu.cn/lxc-images"
        ["ustc"]="https://mirrors.ustc.edu.cn/lxc-images"
        ["sjtu"]="https://mirrors.sjtug.sjtu.edu.cn/lxc-images"
    )

    local is_supported=0
    for os in "${OS_LIST[@]}"; do
        if [ "$os" = "$os_name" ]; then
            is_supported=1
            break
        fi
    done

    if [ $is_supported -eq 0 ]; then
        echo "不支持的系统: $os_name"
        echo "支持的系统: ${OS_LIST[@]}"
        return 1
    fi

    if [ -z "${MIRRORS[$mirror_choice]}" ]; then
        mirror_choice="default"
    fi
    local base_url="${MIRRORS[$mirror_choice]}"
    local api_url="$base_url/meta/1.0/index-system"

    local versions=$(curl -s "$api_url" | grep "^$os_name;" | grep "arm64" | grep "default" | cut -d';' -f2 | sort -u)

    if [ -z "$versions" ]; then
        echo "未找到 $os_name 的 ARM64 架构版本"
        return 1
    fi

    if [ "$version" = "default" ]; then
        version=$(echo "$versions" | tail -n 1)
    else
        if ! echo "$versions" | grep -q "^$version$"; then
            echo "可用版本: "
            echo "$versions"
            echo "选择的版本 $version 不可用 请选择上面列出的版本"
            return 1
        fi
    fi

    local version_info=$(curl -s "$api_url" | grep "^$os_name;$version;" | grep "arm64" | grep "default" | sort -V | tail -n 1)
    
    if [ -z "$version_info" ]; then
        echo "未找到 $os_name $version 的 ARM64 架构版本"
        return 1
    fi

    IFS=';' read -r distro version arch variant date path <<< "$version_info"

    local download_url="${base_url}${path}/rootfs.tar.xz"
    local download_file="/data/local/tmp/${os_name}_${version}_rootfs.tar.xz"

    mkdir -p "$target_dir" /data/local/tmp

    echo "开始下载 $os_name 系统镜像..."
    echo "版本: $version"
    echo "架构: $arch"
    echo "下载地址: $download_url"

    local download_success=0
    if command -v wget >/dev/null 2>&1; then
        echo "使用 wget 下载..."
        if wget -O "$download_file" "$download_url"; then
            download_success=1
        fi
    else
        echo "使用 curl 下载..."
        if curl -L -o "$download_file" "$download_url"; then
            download_success=1
        fi
    fi

    if [ $download_success -eq 0 ]; then
        echo "下载失败"
        echo "请检查以下可能原因: "
        echo "1. 网络连接"
        echo "2. 下载地址是否正确"
        echo "3. 服务器是否可访问"
        echo "完整下载地址: $download_url"
        return 1
    fi

    if [ ! -s "$download_file" ]; then
        echo "下载文件为空"
        rm -f "$download_file"
        return 1
    fi

    echo "正在解压系统镜像..."
    if tar -xJf "$download_file" -C "$target_dir"; then
        echo "解压成功"

        rm -f "$download_file"

        return 0
    else
        echo "解压失败"
        return 1
    fi
}

download_system_menu() {
    while true; do
        clear
        echo "========== 系统镜像下载 =========="
        echo "可下载系统(模块支持): "

        for os in "${OS_LIST[@]}"; do
            echo "- $os"
        done

        echo "支持的镜像源: "
        echo "- default (https://images.linuxcontainers.org)"
        echo "- tuna (清华大学镜像)"
        echo "- ustc (中科大镜像)"
        echo "- sjtu (上海交大镜像)"

        echo "0. 返回上级菜单"
        echo "======================================"

        read -p "请输入要下载的系统: " system_choice

        if [ "$system_choice" = "0" ]; then
            return 0
        fi

        local is_supported=0
        for os in "${OS_LIST[@]}"; do
            if [ "$os" = "$system_choice" ]; then
                is_supported=1
                break
            fi
        done

        if [ $is_supported -eq 0 ]; then
            echo "不支持的系统: $system_choice"
            pause_func
            continue
        fi

        local sys_path="$BASE_DIR/$system_choice"
        if [ -d "$sys_path" ]; then
            echo "系统 $system_choice 已存在"
            read -p "是否继续 默认会删除现有系统? (y/N): " overwrite_choice

            if [[ ! "$overwrite_choice" =~ ^[Yy]$ ]]; then
                echo "操作取消"
                pause_func
                continue
            fi

            read -p "是否创建备份? (y/N): " backup_choice
            
            if [[ "$backup_choice" =~ ^[Yy]$ ]]; then
                create_initial_backup "$system_choice"
            fi

            echo "删除已存在的系统目录..."
            rm -rf "$sys_path"
        fi

        local versions=$(curl -s "https://images.linuxcontainers.org/meta/1.0/index-system" | grep "^$system_choice;" | grep "arm64" | grep "default" | cut -d';' -f2 | sort -u)

        echo "可用版本: "
        echo "$versions"

        local default_version=$(echo "$versions" | head -n 1)

        read -p "选择版本 (留空默认为 $default_version): " version_choice
        version_choice=${version_choice:-$default_version}

        read -p "选择镜像源 (留空为 https://images.linuxcontainers.org): " mirror_choice
        mirror_choice=${mirror_choice:-default}

        if download_system_image "$system_choice" "$mirror_choice" "$version_choice"; then
            echo "系统 $system_choice $version_choice 下载并解压成功"
            read -p "是否立即创建备份? (y/N): " create_backup

            if [[ "$create_backup" =~ ^[Yy]$ ]]; then
                create_initial_backup "$system_choice"
            fi
        else
            echo "系统 $system_choice 下载失败"
        fi

        pause_func
    done
}

delete_system() {
    local os_name="$1"
    local sys_path="$BASE_DIR/$os_name"

    if [ ! -d "$sys_path" ]; then
        echo "系统 $os_name 不存在"
        return 1
    fi

    local backup_files=()
    backup_files+=("$BACKUP_DIR/$os_name.old.tar.gz")
    for i in $(seq 1 2); do
        backup_files+=("$BACKUP_DIR/$os_name.old.$i.tar.gz")
    done

    local has_backup=false
    for file in "${backup_files[@]}"; do
      if [ -f "$file" ]; then
        has_backup=true
        break
      fi
    done

    if $has_backup; then
        read -p "系统存在备份 是否删除备份? (y/N): " delete_backup

        if [[ "$delete_backup" =~ ^[Yy]$ ]]; then
            echo "删除系统备份..."
            for file in "${backup_files[@]}"; do
                if [ -f "$file" ]; then
                    echo "删除备份文件: $file"
                    rm -f "$file"
                fi
            done
        fi
    fi

    echo "删除系统目录: $sys_path"
    rm -rf "$sys_path"

    echo "系统 $os_name 删除成功"
    pause_func
    return 0
}

config_new_system() {
    local new_os="$1"
    local sys_password="${2:-123456}"
    local sys_port="${3:-22}"

    local sys_dir="$BASE_DIR/$new_os"

    local module_path
    if [ -d "/data/adb/lite_modules/$MODULEID" ]; then
        module_path="/data/adb/lite_modules/$MODULEID"
    elif [ -d "/data/adb/modules/$MODULEID" ]; then
        module_path="/data/adb/modules/$MODULEID"
    else
        echo "未找到模块目录"
        return 1
    fi

    if [ ! -d "$sys_dir" ]; then
        echo "系统目录 $sys_dir 不存在"
        return 1
    fi

    local setup_script="$module_path/setup/setup.sh"
    if [ ! -f "$setup_script" ]; then
        echo "setup脚本 $setup_script 不存在"
        return 1
    fi

    local ruri_script="$module_path/bin/ruri"
    if [ ! -f "$ruri_script" ]; then
        echo "ruri $ruri_script 不存在"
        return 1
    fi

    mkdir -p "$sys_dir/tmp" "$sys_dir/usr/local/lib/servicectl/enabled"
    cp "$setup_script" "$sys_dir/tmp/setup.sh"
    cp -r "$module_path/setup/servicectl"/* "$sys_dir/usr/local/lib/servicectl/"

    chmod 777 "$setup_script" "$sys_dir/usr/local/lib/servicectl/servicectl" "$sys_dir/usr/local/lib/servicectl/serviced"

    "$ruri_script" "$sys_dir" /bin/sh /tmp/setup.sh "$new_os" "$sys_password" "$sys_port"

    if [ $? -eq 0 ]; then
        echo "系统 $new_os 基础配置完成"
        echoRgb "请牢记你的密码: $sys_password 和端口: $sys_port" 3
        return 0
    else
        echo "系统 $new_os 基础配置失败"
        return 1
    fi
}

switch_lxc_os() {
    local new_os="$1"

    local valid_os=0
    for os in "${OS_LIST[@]}"; do
        if [[ "$os" == "$new_os" ]]; then
            valid_os=1
            break
        fi
    done

    if [ $valid_os -eq 0 ]; then
        echo "不支持切换到 $new_os 系统"
        return 1
    fi

    if [ -d "/data/adb/lite_modules/$MODULEID" ]; then
        MODULE_PATH="/data/adb/lite_modules/$MODULEID"
    elif [ -d "/data/adb/modules/$MODULEID" ]; then
        MODULE_PATH="/data/adb/modules/$MODULEID"
    else
        echo "未找到模块目录"
        return 1
    fi

    local CONFIG_FILE="$MODULE_PATH/config.conf"

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "配置文件 $CONFIG_FILE 不存在"
        return 1
    fi

    sed -i "s/^RURIMA_LXC_OS=.*/RURIMA_LXC_OS=$new_os/" "$CONFIG_FILE"
    sed -i "s|^CONTAINER_DIR=.*|CONTAINER_DIR=$BASE_DIR/$new_os|" "$CONFIG_FILE"

    if [ $? -eq 0 ]; then
        echo "成功将系统切换为 $new_os"

        read -p "是否需要配置新系统的基础设置? (y/N): " config_choice

        if [[ "$config_choice" =~ ^[Yy]$ ]]; then
            read -p "请输入系统密码 (留空默认为 123456): " sys_password
            read -p "请输入SSH端口号 (留空默认为 22): " sys_port
            
            config_new_system "$new_os" "$sys_password" "$sys_port"
        fi

        return 0
    else
        echo "修改系统失败"
        return 1
    fi
}

print_installed_systems() {
    local installed_systems=()
    for os in "${OS_LIST[@]}"; do
        if [ -d "$BASE_DIR/$os" ]; then
            installed_systems+=("$os")
        fi
    done

    echo "已安装系统 (${#installed_systems[@]}): "
    if [ ${#installed_systems[@]} -eq 0 ]; then
        echo "  - 无"
    else
      for sys in "${installed_systems[@]}"; do
        echo "  - $sys"
      done
    fi
}

main_menu() {
    while true; do
        clear
        echo "========== 系统管理工具 v1.0 =========="
        echo "系统环境: "
        echo "- 基础目录: $BASE_DIR"
        echo "- 备份目录: $BACKUP_DIR"
        echo "-----------------------------------"

        print_installed_systems

        echo "-----------------------------------"
        echo "主菜单: "
        echo "1. 系统备份管理"
        echo "2. 检查已安装系统"
        echo "3. 检查系统版本(从镜像源)"
        echo "4. 下载系统镜像"
        echo "5. 删除系统"
        echo "6. 切换LXC系统"
        echoRgb "0. 退出" 1
        echo "======================================"

        read -p "请选择操作 [0-6]: " main_choice

        case $main_choice in
            1)
                system_backup_menu
                ;;
            2)
                check_installed_systems
                pause_func
                ;;
            3)
                read -p "请输入系统名称: " os_name
                read -p "请输入镜像源 (default/tuna/ustc/sjtu): " mirror
                check_os_versions "$os_name" "$mirror"
                pause_func
                ;;
            4)
                download_system_menu
                ;;
            5)
                local installed_systems=()
                for os in "${OS_LIST[@]}"; do
                    if [ -d "$BASE_DIR/$os" ]; then
                        installed_systems+=("$os")
                    fi
                done

                if [ ${#installed_systems[@]} -eq 0 ]; then
                    echo "当前没有已安装的系统"
                    pause_func
                else
                    echo "已安装系统: "
                    for ((i=0; i<${#installed_systems[@]}; i++)); do
                        echo "$((i+1)). ${installed_systems[i]}"
                    done

                    read -p "选择要删除的系统 (0 返回): " delete_choice

                    if [[ "$delete_choice" =~ ^[0-9]+$ ]] && [ "$delete_choice" -gt 0 ] && [ "$delete_choice" -le ${#installed_systems[@]} ]; then
                        local system_to_delete="${installed_systems[$((delete_choice-1))]}"
                        read -p "确定要删除系统 $system_to_delete 吗? (y/N): " confirm
                        if [[ "$confirm" =~ ^[yY]$ ]]; then
                            delete_system "$system_to_delete"
                        fi
                    elif [ "$delete_choice" -eq 0 ]; then
                        :
                    else
                        echo "无效的选择"
                    fi
                    pause_func
                fi
                ;;
            6)
                read -p "请输入要切换的系统名称: " new_os
                if [ -z "$new_os" ]; then
                  echo "系统名称不能为空"
                elif [ -d "$BASE_DIR/$new_os" ]; then
                    switch_lxc_os "$new_os"
                else
                    echo "系统 $new_os 未安装"
                    echo "请先下载系统镜像或检查已安装系统路径"
                fi
                pause_func
                ;;
            0)
                echo "感谢使用 再见! "
                sleep 5
                exit 0
                ;;
            *)
                echo "无效的选择"
                pause_func
                ;;
        esac
    done
}

main_menu

rm -f $(readlink -f "$0")
