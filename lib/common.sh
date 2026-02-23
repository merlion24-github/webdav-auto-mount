#!/bin/bash

# 日志级别
LOG_LEVEL="info"

# 日志文件
LOG_FILE="/Users/merlion/Library/Logs/WebDAV-Mount/mount_log_$(date +%Y-%m-%d_%H-%M-%S).txt"

# 确保日志目录存在
mkdir -p "$(dirname "$LOG_FILE")"

# 日志函数
log() {
    local message="$1"
    local timestamp=$(date "[20%y-%m-%d %H:%M:%S]")
    echo "$timestamp $message" >> "$LOG_FILE"
    echo "$timestamp $message"
}

# 错误日志函数
log_error() {
    local message="$1"
    local error_code="$2"
    local error_type="$3"
    local timestamp=$(date "[20%y-%m-%d %H:%M:%S]")
    echo "$timestamp ERROR: $message" >> "$LOG_FILE"
    echo "$timestamp ERROR: $message"
    
    # 如果提供了错误代码和类型，记录更详细的信息
    if [ -n "$error_code" ]; then
        echo "$timestamp ERROR CODE: $error_code" >> "$LOG_FILE"
    fi
    if [ -n "$error_type" ]; then
        echo "$timestamp ERROR TYPE: $error_type" >> "$LOG_FILE"
    fi
}

# 检查工具是否安装
check_tool() {
    local tool="$1"
    if ! command -v "$tool" &> /dev/null; then
        log_error "工具未安装: $tool"
        exit 1
    fi
}

# 检查目录是否存在，不存在则创建
check_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        log "创建目录: $dir"
        mkdir -p "$dir"
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi
    return 0
}

# 执行命令并记录输出
exec_cmd() {
    local cmd="$1"
    local description="$2"
    log "执行命令: $description"
    log "命令: $cmd"
    
    local result=$($cmd 2>&1)
    local exit_code=$?
    
    log "命令输出: $result"
    log "退出代码: $exit_code"
    
    return $exit_code
}

# 安全初始化
secure_init() {
    log "信息：开始安全初始化"
    
    # 检查脚本权限
    local script_path="$(realpath "$0")"
    local script_perm=$(stat -f "%A" "$script_path")
    log "信息：检查脚本权限：$script_path"
    log "信息：当前权限：$script_perm"
    
    # 检查配置文件权限
    local config_perm=$(stat -f "%A" "$CONFIG_FILE" 2>/dev/null || echo "N/A")
    log "信息：检查配置文件权限：$CONFIG_FILE"
    log "信息：当前权限：$config_perm"
    
    # 检查用户权限
    if id -nG | grep -q "admin"; then
        log "信息：当前用户具有管理员权限"
    else
        log "警告：当前用户不具有管理员权限，可能会影响某些操作"
    fi
    
    # 检查系统安全性
    local gatekeeper_status=$(spctl --status 2>&1 || echo "未知")
    log "信息：检查系统安全性"
    log "信息：Gatekeeper 状态：$gatekeeper_status"
    
    # 检查防火墙状态
    local firewall_status=$(defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null || echo "未知")
    if [ "$firewall_status" = "1" ]; then
        log "信息：防火墙已启用"
    else
        log "警告：防火墙未启用，系统安全性可能降低"
    fi
    
    # 清理临时文件
    log "信息：清理临时文件"
    rm -f /tmp/webdav_*.tmp 2>/dev/null
    log "信息：临时文件清理完成"
    
    log "信息：安全初始化完成"
}

# 从配置文件获取服务器信息
get_server_info() {
    local remote="$1"
    jq -r ".servers[] | select(.name == \"$remote\")" "$CONFIG_FILE"
}

# 检查服务器在线状态
check_server_online() {
    local server_ip=$(echo "$1" | sed -E 's|http://([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+):.*|\1|')
    if ping -c 1 -t 3 "$server_ip" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 检查脚本权限
check_script_permissions() {
    local script_path="$1"
    local expected_perm="755"
    local actual_perm=$(stat -f "%Lp" "$script_path" 2>/dev/null || echo "N/A")
    
    if [ "$actual_perm" != "$expected_perm" ]; then
        log "警告：脚本权限不正确，当前权限：$actual_perm，建议：$expected_perm"
        log "尝试修复权限..."
        chmod "$expected_perm" "$script_path"
        if [ $? -eq 0 ]; then
            log "权限修复成功"
        else
            log_error "权限修复失败"
        fi
    fi
}

# 清理旧的挂载进程
cleanup_old_mounts() {
    local remote="$1"
    log "清理旧的rclone挂载进程..."
    pkill -f "rclone mount ${remote}:" 2>/dev/null || log "没有找到旧的rclone挂载进程"
}

# 检查挂载点是否已挂载
is_mounted() {
    local mount_point="$1"
    if mount | grep -q "$mount_point"; then
        return 0
    else
        return 1
    fi
}

# 卸载挂载点
unmount_point() {
    local mount_point="$1"
    log "卸载挂载点：$mount_point"
    umount -f "$mount_point" 2>/dev/null || log "挂载点未挂载或无法卸载"
}

# 生成随机字符串
generate_random_string() {
    local length="$1"
    openssl rand -base64 "$length" | tr -d '+/=' | head -c "$length"
}

# 检查环境变量
check_environment() {
    log "检查环境变量..."
    
    # 检查PATH
    if echo "$PATH" | grep -q "/usr/local/bin"; then
        log "信息：/usr/local/bin 在 PATH 中"
    else
        log "警告：/usr/local/bin 不在 PATH 中，可能会影响工具执行"
    fi
    
    # 检查HOME
    if [ -n "$HOME" ]; then
        log "信息：HOME 环境变量已设置：$HOME"
    else
        log "错误：HOME 环境变量未设置"
        exit 1
    fi
}

# 检查系统版本
check_system_version() {
    local os_version=$(sw_vers -productVersion)
    log "信息：系统版本：$os_version"
    
    # 检查是否为 macOS
    if [ "$(sw_vers -productName)" != "macOS" ]; then
        log_error "此脚本仅支持 macOS 系统"
        exit 1
    fi
}

# 安全检查
security_check() {
    log "执行安全检查..."
    
    # 检查是否以 root 身份运行
    if [ "$(id -u)" -eq 0 ]; then
        log "警告：以 root 身份运行脚本，可能存在安全风险"
    fi
    
    # 检查配置文件权限
    if [ -f "$CONFIG_FILE" ]; then
        local config_perm=$(stat -f "%Lp" "$CONFIG_FILE")
        if [ "$config_perm" -gt "644" ]; then
            log "警告：配置文件权限过于宽松，建议设置为 644"
        fi
    fi
    
    log "安全检查完成"
}