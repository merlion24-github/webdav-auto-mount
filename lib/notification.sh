#!/bin/bash

# 发送挂载成功通知
send_mount_success() {
    local name="$1"
    local mount_point="$2"
    
    # 显示通知
    osascript -e "display notification \"已成功挂载到 ${mount_point}\" with title \"WebDAV 挂载成功\" subtitle \"${name}\""
    
    # 记录通知
    log "信息：发送通知：WebDAV 挂载成功 - ${name} 已成功挂载到 ${mount_point}"
}

# 发送挂载失败通知
send_mount_failure() {
    local name="$1"
    local error="$2"
    
    # 显示通知
    osascript -e "display notification \"错误：${error}\" with title \"WebDAV 挂载失败\" subtitle \"${name}\""
    
    # 记录通知
    log "信息：发送通知：WebDAV 挂载失败 - ${name} 挂载失败：${error}"
}

# 发送脚本执行完成通知
send_script_completed() {
    local success_count="$1"
    local failure_count="$2"
    
    if [ "$success_count" -gt 0 ] && [ "$failure_count" -eq 0 ]; then
        # 全部成功
        osascript -e "display notification \"所有服务器挂载成功（共 ${success_count} 个）\" with title \"WebDAV 挂载脚本\" subtitle \"执行完成\""
        log "信息：发送通知：WebDAV 挂载脚本 - 所有服务器挂载成功（共 ${success_count} 个）"
    elif [ "$success_count" -gt 0 ] && [ "$failure_count" -gt 0 ]; then
        # 部分成功
        osascript -e "display notification \"成功 ${success_count} 个，失败 ${failure_count} 个\" with title \"WebDAV 挂载脚本\" subtitle \"执行完成\""
        log "信息：发送通知：WebDAV 挂载脚本 - 挂载完成：成功 ${success_count} 个，失败 ${failure_count} 个"
    else
        # 全部失败
        osascript -e "display notification \"所有服务器挂载失败（共 ${failure_count} 个）\" with title \"WebDAV 挂载脚本\" subtitle \"执行完成\""
        log "信息：发送通知：WebDAV 挂载脚本 - 所有服务器挂载失败（共 ${failure_count} 个）"
    fi
}

# 发送服务检测通知
send_service_check() {
    local name="$1"
    local status="$2"
    local message="$3"
    
    if [ "$status" = "success" ]; then
        osascript -e "display notification \"${message}\" with title \"WebDAV 服务检测\" subtitle \"${name}：成功\""
    else
        osascript -e "display notification \"${message}\" with title \"WebDAV 服务检测\" subtitle \"${name}：失败\""
    fi
    
    log "信息：发送通知：WebDAV 服务检测 - ${name}：${status} - ${message}"
}

# 发送服务器唤醒通知
send_server_wake() {
    local name="$1"
    local status="$2"
    local message="$3"
    
    if [ "$status" = "success" ]; then
        osascript -e "display notification \"${message}\" with title \"服务器唤醒\" subtitle \"${name}：成功\""
    else
        osascript -e "display notification \"${message}\" with title \"服务器唤醒\" subtitle \"${name}：失败\""
    fi
    
    log "信息：发送通知：服务器唤醒 - ${name}：${status} - ${message}"
}

# 发送错误通知
send_error_notification() {
    local title="$1"
    local subtitle="$2"
    local message="$3"
    
    osascript -e "display notification \"${message}\" with title \"${title}\" subtitle \"${subtitle}\""
    log "信息：发送通知：${title} - ${subtitle} - ${message}"
}

# 发送警告通知
send_warning_notification() {
    local title="$1"
    local subtitle="$2"
    local message="$3"
    
    osascript -e "display notification \"${message}\" with title \"${title}\" subtitle \"${subtitle}\""
    log "信息：发送通知：${title} - ${subtitle} - ${message}"
}

# 发送信息通知
send_info_notification() {
    local title="$1"
    local subtitle="$2"
    local message="$3"
    
    osascript -e "display notification \"${message}\" with title \"${title}\" subtitle \"${subtitle}\""
    log "信息：发送通知：${title} - ${subtitle} - ${message}"
}