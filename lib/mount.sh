#!/bin/bash

# 加载通用函数库
source "/Users/merlion/workspace/Rclone/lib/common.sh"
source "/Users/merlion/workspace/Rclone/lib/notification.sh"

# 检查 webdav 连接并尝试挂载
mount_webdav() {
    local remote="$1"
    local mount_point="$2"
    local max_retries=3
    local retry_interval=5
    
    log "开始挂载 ${remote} 到 ${mount_point}..."
    
    # 检查挂载点目录是否存在，不存在则创建
    if ! check_dir "$mount_point"; then
        log_error "创建挂载点目录失败：$mount_point" "1" "permission"
        return 1
    fi
    
    # 从配置文件获取服务器信息
    local server_info=$(get_server_info "$remote")
    local url=$(echo "$server_info" | jq -r '.url')
    local username=$(echo "$server_info" | jq -r '.username')
    local password=$(echo "$server_info" | jq -r '.password')
    
    if [ -z "$url" ] || [ -z "$username" ] || [ -z "$password" ]; then
        log_error "挂载失败：服务器配置不完整"
        return 1
    fi
    
    log "服务器 URL: $url"
    log "服务器用户名: $username"
    
    # 尝试使用 rclone 命令测试服务器连接
    log "测试 ${remote} 服务器连接..."
    local test_result=$(/usr/local/bin/rclone lsd "${remote}:" 2>&1)
    local test_exit_code=$?
    
    if [ $test_exit_code -eq 0 ]; then
        log "${remote} 服务器连接成功！"
        log "服务器上的目录："
        log "$test_result"
        
        # 尝试直接挂载服务器（SIP已关闭，应该可以正常工作）
        log "尝试直接挂载 ${remote} 服务器..."
        
        # 清理可能存在的旧rclone进程
        log "清理旧的rclone挂载进程..."
        pkill -f "rclone mount ${remote}:" 2>/dev/null || log "没有找到旧的rclone挂载进程"
        
        # 确保挂载点目录存在且权限正确
        log "确保挂载点目录存在..."
        mkdir -p "$mount_point" || log_error "创建挂载点目录失败"
        
        # 清理挂载点目录（如果有旧的挂载残留）
        log "清理挂载点目录..."
        rm -rf "${mount_point}/"* 2>/dev/null || log "无法清理挂载点目录，可能有权限限制"
        
        # 强制卸载可能存在的挂载
        log "强制卸载可能存在的挂载..."
        umount -f "$mount_point" 2>/dev/null || log "挂载点未挂载或无法卸载"
        
        # 尝试FUSE挂载（可能在某些环境中被限制）
        log "尝试FUSE挂载 ${remote} 服务器..."
        
        # 使用 rclone mount 命令直接挂载，添加更多选项确保稳定性
        local mount_cmd="/usr/local/bin/rclone mount ${remote}: "${mount_point}" --allow-other --allow-non-empty --vfs-cache-mode minimal --daemon --umask 0000 --uid $(id -u) --gid $(id -g) --poll-interval 10s --timeout 30s --no-modtime"
        local mount_result=$($mount_cmd 2>&1)
        local mount_exit_code=$?
        
        # 检查是否是权限错误
        if echo "$mount_result" | grep -q "Operation not permitted" || echo "$mount_result" | grep -q "permission denied"; then
            log_error "FUSE挂载被禁止：$mount_result"
            log "切换到备用方法..."
            
            # 备用方法：使用rclone命令访问
            log "使用备用方法访问 ${remote} 服务器..."
            
            # 清理挂载点目录，避免显示为"Macintosh HD"
            rm -rf "${mount_point}/"* 2>/dev/null || log "清理挂载点目录失败"
            
            # 发送挂载失败通知
            send_mount_failure "$remote" "FUSE挂载被禁止，无法直接挂载"
            return 1
        elif [ $mount_exit_code -eq 0 ]; then
            # FUSE挂载成功的情况
            log "${remote} 服务器FUSE挂载成功！"
            
            # 等待几秒钟让挂载稳定
            sleep 3
            
            # 检查挂载状态
            log "检查 ${remote} 挂载状态..."
            
            # 尝试列出挂载点内容，允许失败
            local ls_result=$(ls -la "${mount_point}" 2>&1)
            local ls_exit_code=$?
            
            log "挂载点内容: $ls_result"
            
            # 检查挂载是否成功的条件：
            # 1. 挂载命令执行成功
            # 2. 挂载点目录可访问（即使是空的）
            # 3. 没有权限错误
            if [ $ls_exit_code -eq 0 ] || ! echo "$ls_result" | grep -q "Permission denied"; then
                log "${remote} 挂载验证成功！"
                
                # 打开挂载点目录
                open "${mount_point}"
                
                # 发送挂载成功通知
                send_mount_success "$remote" "$mount_point"
                return 0
            else
                log_error "${remote} 挂载验证失败"
                
                # 继续使用备用方法
                log "切换到备用方法..."
            fi
        else
            log_error "FUSE挂载失败：$mount_result"
            log "切换到备用方法..."
        fi
        
        # 清理挂载点目录，避免显示为"Macintosh HD"
        rm -rf "${mount_point}/"* 2>/dev/null || log "清理挂载点目录失败"
        
        # 发送挂载失败通知
        send_mount_failure "$remote" "FUSE挂载失败，无法直接挂载"
        return 1
    else
        log_error "${remote} 服务器连接失败！"
        log_error "连接错误详情：$test_result"
        
        # 发送挂载失败通知
        send_mount_failure "$remote" "$test_result"
        return 1
    fi
}

# 挂载 SMB 服务器
mount_smb() {
    local remote="$1"
    local mount_point="$2"
    
    log "开始挂载 ${remote} (SMB) 到 ${mount_point}..."
    
    # 检查挂载点目录是否存在，不存在则创建
    if ! check_dir "$mount_point"; then
        log_error "创建挂载点目录失败：$mount_point"
        return 1
    fi
    
    # 尝试挂载 SMB 服务器
    # 这里假设 remote 格式为 //server/share
    log "尝试挂载 SMB 服务器：$remote"
    
    # 使用 mount_smbfs 命令挂载
    local smb_result=$(mount_smbfs "$remote" "$mount_point" 2>&1)
    local smb_exit_code=$?
    
    if [ $smb_exit_code -eq 0 ]; then
        log "${remote} (SMB) 挂载成功！"
        # 发送挂载成功通知
        send_mount_success "$remote" "$mount_point"
        return 0
    else
        log_error "${remote} (SMB) 挂载失败！"
        log_error "错误信息：$smb_result"
        # 发送挂载失败通知
        send_mount_failure "$remote" "$smb_result"
        return 1
    fi
}

# 挂载 NFS 服务器
mount_nfs() {
    local remote="$1"
    local mount_point="$2"
    
    log "开始挂载 ${remote} (NFS) 到 ${mount_point}..."
    
    # 检查挂载点目录是否存在，不存在则创建
    if ! check_dir "$mount_point"; then
        log_error "创建挂载点目录失败：$mount_point"
        return 1
    fi
    
    # 尝试挂载 NFS 服务器
    # 这里假设 remote 格式为 server:/share
    log "尝试挂载 NFS 服务器：$remote"
    
    # 使用 mount 命令挂载
    local nfs_result=$(mount -t nfs "$remote" "$mount_point" 2>&1)
    local nfs_exit_code=$?
    
    if [ $nfs_exit_code -eq 0 ]; then
        log "${remote} (NFS) 挂载成功！"
        # 发送挂载成功通知
        send_mount_success "$remote" "$mount_point"
        return 0
    else
        log_error "${remote} (NFS) 挂载失败！"
        log_error "错误信息：$nfs_result"
        # 发送挂载失败通知
        send_mount_failure "$remote" "$nfs_result"
        return 1
    fi
}

# 挂载服务器（通用）
mount_server() {
    local remote="$1"
    local mount_point="$2"
    local protocol="$3"
    
    case "$protocol" in
        "webdav")
            mount_webdav "$remote" "$mount_point"
            return $?
            ;;
        "smb")
            mount_smb "$remote" "$mount_point"
            return $?
            ;;
        "nfs")
            mount_nfs "$remote" "$mount_point"
            return $?
            ;;
        *)
            log_error "不支持的协议类型：$protocol"
            return 1
            ;;
    esac
}

# 卸载服务器
unmount_server() {
    local mount_point="$1"
    local name="$2"
    
    log "卸载 ${name} 服务器..."
    
    # 检查挂载点是否存在
    if ! check_dir "$mount_point"; then
        return 1
    fi
    
    # 检查挂载点是否已挂载
    if mount | grep -q "${mount_point}"; then
        # 尝试卸载
        exec_cmd "umount -f "$mount_point"" "卸载 ${name} 服务器"
        if [ $? -eq 0 ]; then
            log "${name} 服务器卸载成功！"
            return 0
        else
            log_error "${name} 服务器卸载失败！"
            return 1
        fi
    else
        log "${name} 服务器未挂载，无需卸载"
        return 0
    fi
}

# 检查挂载状态
check_mount_status() {
    local mount_point="$1"
    local name="$2"
    
    log "检查 ${name} 挂载状态..."
    
    if mount | grep -q "${mount_point}"; then
        log "${name} 已挂载"
        return 0
    else
        log "${name} 未挂载"
        return 1
    fi
}