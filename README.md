# WebDAV自动挂载系统

## 项目简介

WebDAV自动挂载系统是一个为macOS设计的自动化工具，用于在系统启动时自动挂载WebDAV网络硬盘。该系统解决了服务器慢启动、挂载状态不明确、权限问题等常见痛点，提供了稳定、可靠的网络存储访问解决方案。

## 功能特性

- ✅ **自动挂载**：系统重启后自动挂载网络硬盘
- ✅ **智能检测**：自动检测服务器在线状态和WebDAV服务就绪状态
- ✅ **慢启动适应**：支持服务器慢启动场景，智能等待服务就绪
- ✅ **并行处理**：多服务器并行挂载，提高效率
- ✅ **详细反馈**：系统通知提供挂载状态反馈
- ✅ **错误处理**：完善的错误处理和日志记录
- ✅ **权限管理**：智能处理权限问题
- ✅ **图形化界面**：提供LaunchAgent配置文件

## 系统要求

- macOS 10.14或更高版本
- rclone 1.60.0或更高版本
- FUSE for macOS（可选，用于本地文件系统体验）
- jq（用于JSON配置文件处理）
- 已关闭SIP保护（用于FUSE挂载）

## 安装与配置

### 1. 安装依赖

```bash
# 安装Homebrew（如果尚未安装）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装依赖工具
brew install rclone jq macfuse
```

### 2. 关闭SIP保护（可选，用于FUSE挂载）

1. 重启Mac并按住Command+R进入恢复模式
2. 打开终端并执行：`csrutil disable`
3. 重启Mac

### 3. 配置服务器信息

编辑 `config.json` 文件，添加或修改服务器配置：

```json
{
  "servers": [
    {
      "name": "DS-01",
      "url": "http://192.168.2.56:5005",
      "username": "your_username",
      "password": "your_password",
      "mount_point": "/Users/your_username/Servers/DS-01",
      "wake_on_lan": false,
      "max_retries": 40,
      "retry_interval": 3,
      "protocol": "webdav",
      "timeout": 120
    }
  ]
}
```

### 4. 配置自动启动

```bash
# 复制LaunchAgent配置文件
cp com.rclone.automount-webdav.plist ~/Library/LaunchAgents/

# 加载配置
launchctl load ~/Library/LaunchAgents/com.rclone.automount-webdav.plist

# 启动服务
launchctl start com.rclone.automount-webdav
```

## 使用方法

### 手动启动

```bash
# 直接运行脚本
bash mount_webdav.sh

# 或使用图形化应用
open AutoMountWebDAVRunner.app
```

### 查看日志

```bash
# 查看日志文件
ls -la ~/Library/Logs/WebDAV-Mount/
cat ~/Library/Logs/WebDAV-Mount/latest.log
```

### 检查挂载状态

```bash
# 检查所有挂载
mount | grep -E 'DS-01|DS-02'

# 检查挂载点
ls -la /Users/your_username/Servers/
```

## 故障排除

### 常见问题

1. **挂载失败，显示"Permission denied"**
   - 确保已关闭SIP保护
   - 检查挂载点目录权限
   - 尝试重新启动rclone进程

2. **服务器连接失败**
   - 检查网络连接
   - 验证服务器URL和端口
   - 确认服务器WebDAV服务已启动

3. **自动启动不工作**
   - 检查LaunchAgent配置文件权限
   - 确保脚本路径正确
   - 查看系统日志：`log show --predicate 'subsystem == "com.apple.launchd.peruser.501"' --info`

4. **挂载点显示"Macintosh HD"**
   - 这是由于挂载点目录中存在特定文件导致的
   - 确保挂载点目录为空
   - 重新运行挂载脚本

### 日志分析

日志文件位于 `~/Library/Logs/WebDAV-Mount/` 目录，包含详细的挂载过程和错误信息。分析日志可以帮助定位具体问题。

## 项目结构

```
webdav-auto-mount/
├── mount_webdav.sh          # 主脚本，处理服务器挂载逻辑
├── AutoMountWebDAVRunner.app # 图形化启动应用
├── config.json              # 服务器配置文件
├── com.rclone.automount-webdav.plist # LaunchAgent配置
└── lib/                     # 函数库目录
    ├── common.sh            # 通用函数（日志、错误处理等）
    ├── service.sh           # 服务检测函数
    ├── mount.sh             # 挂载相关函数
    └── notification.sh      # 通知函数
```

## 技术实现

- **主要语言**：Bash, AppleScript
- **核心工具**：rclone, FUSE for macOS
- **辅助工具**：jq（JSON处理）, ping（网络检测）
- **系统集成**：LaunchAgent, 系统通知

## 安全注意事项

1. **密码存储**：配置文件中的密码以明文形式存储，请确保文件权限正确（644）
2. **网络安全**：建议在安全的网络环境中使用，或配置HTTPS
3. **系统权限**：关闭SIP可能会降低系统安全性，请谨慎操作
4. **日志安全**：日志文件可能包含敏感信息，请定期清理

## 未来计划

- [ ] 开发图形化配置界面
- [ ] 支持远程管理挂载状态
- [ ] 添加挂载状态监控和自动修复机制
- [ ] 扩展支持SMB、NFS等其他网络存储协议
- [ ] 增加配置文件云同步功能

## 贡献

欢迎提交Issue和Pull Request，帮助改进这个项目。

## 许可证

本项目采用MIT许可证，详见LICENSE文件。

## 联系方式

如有问题或建议，请通过GitHub Issues联系。

---

**版本**: v2.0
**更新日期**: 2026-02-23