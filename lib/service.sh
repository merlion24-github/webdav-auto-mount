#!/bin/bash

# 加载通用函数库
source "/Users/merlion/workspace/Rclone/lib/common.sh"

# 检查 WebDAV 服务状态
check_webdav_service() {
    local url="$1"
    local username="$2"
    local password="$3"
    
    # 从 URL 中提取主机和端口
    local host=$(echo "$url" | sed -E 's|http://([^:]+):([0-9]+).*|\1|')
    local port=$(echo "$url" | sed -E 's|http://([^:]+):([0-9]+).*|\2|')
    
    if [ -z "$host" ] || [ -z "$port" ]; then
        log_error "无法从 URL 中提取主机和端口：$url"
        return 1
    fi
    
    log "检查 WebDAV 服务状态：$host:$port"
    
    # 尝试使用 curl 检查服务是否可访问
    local curl_result=$(curl -s -o /dev/null -w "%{http_code}" --user "$username:$password" "$url")
    local curl_exit_code=$?
    
    log "WebDAV 服务检查结果：HTTP 状态码 = $curl_result, 退出代码 = $curl_exit_code"
    
    # 检查结果
    if [ $curl_exit_code -eq 0 ] && [ "$curl_result" -eq 200 ]; then
        log "WebDAV 服务状态：正常"
        return 0
    elif [ $curl_exit_code -eq 0 ] && [ "$curl_result" -eq 401 ]; then
        log "WebDAV 服务状态：需要认证（这是正常的）"
        return 0
    else
        log "WebDAV 服务状态：异常"
        return 1
    fi
}

# 等待服务就绪
wait_for_service() {
    local name="$1"
    local url="$2"
    local username="$3"
    local password="$4"
    local timeout="$5"
    
    log "开始等待 ${name} 的 WebDAV 服务就绪，超时时间：${timeout} 秒..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    while [ $(date +%s) -lt $end_time ]; do
        log "检查 ${name} 的 WebDAV 服务状态..."
        
        if check_webdav_service "$url" "$username" "$password"; then
            log "${name} 的 WebDAV 服务已就绪！"
            local elapsed_time=$(( $(date +%s) - start_time ))
            log "${name} 的 WebDAV 服务已就绪，耗时 ${elapsed_time} 秒"
            return 0
        fi
        
        # 等待一段时间后再次检查
        sleep 3
    done
    
    log_error "${name} 的 WebDAV 服务在 ${timeout} 秒内未就绪"
    return 1
}

# 检查服务器在线状态
check_server_status() {
    local name="$1"
    local url="$2"
    
    # 从 URL 中提取主机
    local host=$(echo "$url" | sed -E 's|http://([^:]+):.*|\1|')
    
    if [ -z "$host" ]; then
        log_error "无法从 URL 中提取主机：$url"
        return 1
    fi
    
    log "检查 ${name} 服务器在线状态：$host"
    
    # 尝试 ping 服务器
    if ping -c 1 -t 3 "$host" > /dev/null 2>&1; then
        log "${name} 服务器在线"
        return 0
    else
        log "${name} 服务器离线"
        return 1
    fi
}

# 唤醒服务器（Wake-on-LAN）
wake_server() {
    local name="$1"
    local mac_address="$2"
    
    if [ -z "$mac_address" ]; then
        log_error "${name} 服务器 MAC 地址未配置"
        return 1
    fi
    
    log "尝试唤醒 ${name} 服务器：$mac_address"
    
    # 使用 wakeonlan 命令唤醒服务器
    if command -v wakeonlan &> /dev/null; then
        local wake_result=$(wakeonlan "$mac_address" 2>&1)
        local wake_exit_code=$?
        
        if [ $wake_exit_code -eq 0 ]; then
            log "成功发送唤醒数据包到 ${name} 服务器"
            return 0
        else
            log_error "发送唤醒数据包失败：$wake_result"
            return 1
        fi
    else
        log_error "wakeonlan 命令未安装，无法唤醒服务器"
        return 1
    fi
}

# 处理服务器（包括唤醒、检查状态、等待服务就绪）
process_server() {
    local name="$1"
    local url="$2"
    local username="$3"
    local password="$4"
    local mount_point="$5"
    local wake_on_lan="$6"
    local max_retries="$7"
    local retry_interval="$8"
    local protocol="$9"
    local timeout="${10}"
    
    log ""
    log "===== 处理 ${name} ======"
    
    # 检查服务器状态
    if ! check_server_status "$name" "$url"; then
        # 如果配置了唤醒功能，尝试唤醒服务器
        if [ "$wake_on_lan" = "true" ]; then
            # 这里应该从配置中获取 MAC 地址，暂时使用占位符
            local mac_address="00:11:22:33:44:55"
            wake_server "$name" "$mac_address"
            
            # 等待服务器启动
            log "等待 ${name} 服务器启动..."
            sleep 30
        else
            log_error "${name} 服务器离线，且未配置唤醒功能"
            return 1
        fi
    fi
    
    # 检查服务器状态
    if check_server_status "$name" "$url"; then
        log "${name} 服务器在线，检查 ${protocol} 服务状态..."
        
        # 等待服务就绪
        if wait_for_service "$name" "$url" "$username" "$password" "$timeout"; then
            log "${name} 的 ${protocol} 服务已就绪，准备挂载..."
            
            # 执行挂载
            mount_server "$name" "$mount_point" "$protocol"
            return $?
        else
            log_error "${name} 的 ${protocol} 服务未就绪，无法挂载"
            return 1
        fi
    else
        log_error "${name} 服务器离线，无法挂载"
        return 1
    fi
}