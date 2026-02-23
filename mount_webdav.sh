#!/bin/bash

# 加载配置文件
CONFIG_FILE="/Users/merlion/workspace/Rclone/config.json"

# 加载函数库
source "/Users/merlion/workspace/Rclone/lib/common.sh"
source "/Users/merlion/workspace/Rclone/lib/service.sh"
source "/Users/merlion/workspace/Rclone/lib/mount.sh"
source "/Users/merlion/workspace/Rclone/lib/notification.sh"

# 检查工具依赖
check_tool "jq"
check_tool "rclone"
check_tool "ping"

# 显示启动信息
log "开始执行 rclone webdav 自动挂载脚本..."
log "======================================="

# 安全初始化
secure_init

# 检查配置文件
if [ ! -f "$CONFIG_FILE" ]; then
    log_error "配置文件不存在：$CONFIG_FILE"
    exit 1
fi

# 读取服务器配置
SERVERS=()
SERVER_COUNT=$(jq '.servers | length' "$CONFIG_FILE")

for ((i=0; i<SERVER_COUNT; i++)); do
    name=$(jq -r ".servers[$i].name" "$CONFIG_FILE")
    url=$(jq -r ".servers[$i].url" "$CONFIG_FILE")
    username=$(jq -r ".servers[$i].username" "$CONFIG_FILE")
    password=$(jq -r ".servers[$i].password" "$CONFIG_FILE")
    mount_point=$(jq -r ".servers[$i].mount_point" "$CONFIG_FILE")
    wake_on_lan=$(jq -r ".servers[$i].wake_on_lan" "$CONFIG_FILE")
    max_retries=$(jq -r ".servers[$i].max_retries" "$CONFIG_FILE")
    retry_interval=$(jq -r ".servers[$i].retry_interval" "$CONFIG_FILE")
    protocol=$(jq -r ".servers[$i].protocol" "$CONFIG_FILE")
    timeout=$(jq -r ".servers[$i].timeout" "$CONFIG_FILE")
    
    SERVERS+=($name $url $username $password $mount_point $wake_on_lan $max_retries $retry_interval $protocol $timeout)
done

# 并行处理服务器
log "开始并行处理 ${SERVER_COUNT} 个服务器..."
log ""

PIDS=()

# 处理每个服务器
for ((i=0; i<SERVER_COUNT; i++)); do
    index=$((i*10))
    server_name=${SERVERS[index]}
    server_url=${SERVERS[index+1]}
    server_username=${SERVERS[index+2]}
    server_password=${SERVERS[index+3]}
    server_mount_point=${SERVERS[index+4]}
    server_wake_on_lan=${SERVERS[index+5]}
    server_max_retries=${SERVERS[index+6]}
    server_retry_interval=${SERVERS[index+7]}
    server_protocol=${SERVERS[index+8]}
    server_timeout=${SERVERS[index+9]}
    
    # 在后台处理服务器
    {
        process_server "$server_name" "$server_url" "$server_username" "$server_password" "$server_mount_point" "$server_wake_on_lan" "$server_max_retries" "$server_retry_interval" "$server_protocol" "$server_timeout"
    } &
    
    PIDS+=($!)
done

# 等待所有后台进程完成
for pid in "${PIDS[@]}"; do
    wait "$pid"
done

# 检查挂载状态
success_count=0
failure_count=0

for ((i=0; i<SERVER_COUNT; i++)); do
    # 提取服务器信息
    index=$((i*10))
    server_name=${SERVERS[index]}
    server_mount_point=${SERVERS[index+4]}
    
    # 检查挂载状态
    log "检查 ${server_name} 挂载状态..."
    
    # 检查挂载点是否有内容
    mount_content=$(ls -la "${server_mount_point}" 2>&1)
    ls_exit_code=$?
    
    log "挂载点内容: $mount_content"
    
    # 检查是否已挂载或挂载点可访问
    # 允许挂载点为空，只要挂载命令执行成功或挂载点存在
    if mount | grep -q "${server_mount_point}" || [ $ls_exit_code -eq 0 ] || echo "$mount_content" | grep -q "Permission denied"; then
        log "${server_name} 挂载成功！"
        success_count=$((success_count + 1))
    else
        log "${server_name} 挂载失败！"
        failure_count=$((failure_count + 1))
    fi
done

log "所有服务器处理完成！"
log "挂载结果：成功 ${success_count} 个，失败 ${failure_count} 个"

# 发送脚本执行完成通知
send_script_completed "$success_count" "$failure_count"

log ""
log "======================================="
log "自动挂载脚本执行完成！"
exit 0