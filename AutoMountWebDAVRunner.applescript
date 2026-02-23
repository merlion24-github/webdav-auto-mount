-- AutoMountWebDAVRunner.applescript
-- 用于启动 WebDAV 自动挂载脚本的 AppleScript

-- 设置工作目录
set workingDir to "/Users/merlion/workspace/Rclone"

-- 设置脚本路径
set mountScriptPath to workingDir & "/mount_webdav.sh"

-- 显示启动信息
display dialog "正在启动 WebDAV 自动挂载系统..." buttons {"确定"} default button 1 with title "WebDAV 挂载系统"

-- 执行挂载脚本
try
    -- 设置环境变量
    set envPath to "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    set envHome to "/Users/merlion"
    
    -- 执行 bash 脚本
    set shellCommand to "export PATH=\"" & envPath & "\" && export HOME=\"" & envHome & "\" && cd \"" & workingDir & "\" && bash \"" & mountScriptPath & "\""
    
    -- 执行命令并捕获输出
    set shellOutput to do shell script shellCommand
    
    -- 显示成功信息
    display dialog "WebDAV 自动挂载脚本执行完成！" & return & return & shellOutput buttons {"确定"} default button 1 with title "执行完成"
    
on error errorMessage number errorNumber
    -- 显示错误信息
    display dialog "执行脚本时发生错误：" & return & return & errorMessage buttons {"确定"} default button 1 with title "执行错误"
    
    -- 记录错误
    log "Error: " & errorMessage & " (" & errorNumber & ")"
end try