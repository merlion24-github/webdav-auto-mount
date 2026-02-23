#!/bin/bash

# WebDAV自动挂载系统 - 发布打包脚本

# 设置变量
PROJECT_NAME="WebDAV-Auto-Mount"
VERSION="2.0.0"
RELEASE_DATE=$(date "%Y-%m-%d")
RELEASE_DIR="/Users/merlion/workspace/Rclone/releases"
BUILD_DIR="$RELEASE_DIR/$PROJECT_NAME-$VERSION"
ZIP_FILE="$RELEASE_DIR/$PROJECT_NAME-$VERSION.zip"

# 确保发布目录存在
mkdir -p "$RELEASE_DIR"

# 显示开始信息
echo "======================================="
echo "WebDAV自动挂载系统 - 发布打包脚本"
echo "版本: $VERSION"
echo "发布日期: $RELEASE_DATE"
echo "======================================="

# 清理旧的构建目录
if [ -d "$BUILD_DIR" ]; then
    echo "清理旧的构建目录..."
    rm -rf "$BUILD_DIR"
fi

# 创建新的构建目录
echo "创建构建目录: $BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$BUILD_DIR/lib"

# 复制核心文件
echo "复制核心文件..."

# 主脚本和配置
cp "mount_webdav.sh" "$BUILD_DIR/"
cp "config.json" "$BUILD_DIR/"
cp "README.md" "$BUILD_DIR/"
cp "com.rclone.automount-webdav.plist" "$BUILD_DIR/"
cp "AutoMountWebDAVRunner.applescript" "$BUILD_DIR/"

# 函数库
cp "lib/common.sh" "$BUILD_DIR/lib/"
cp "lib/mount.sh" "$BUILD_DIR/lib/"
cp "lib/notification.sh" "$BUILD_DIR/lib/"
cp "lib/service.sh" "$BUILD_DIR/lib/"

# 确保脚本有执行权限
echo "设置脚本执行权限..."
chmod +x "$BUILD_DIR/mount_webdav.sh"
chmod +x "$BUILD_DIR/lib/common.sh"
chmod +x "$BUILD_DIR/lib/mount.sh"
chmod +x "$BUILD_DIR/lib/notification.sh"
chmod +x "$BUILD_DIR/lib/service.sh"

# 创建发布说明文件
echo "创建发布说明文件..."
cat > "$BUILD_DIR/RELEASE_NOTES.md" << EOF
# WebDAV自动挂载系统 v$VERSION

## 发布日期
$RELEASE_DATE

## 主要功能

- ✅ **自动挂载**：系统重启后自动挂载网络硬盘
- ✅ **智能检测**：自动检测服务器在线状态和WebDAV服务就绪状态
- ✅ **慢启动适应**：支持服务器慢启动场景，智能等待服务就绪
- ✅ **并行处理**：多服务器并行挂载，提高效率
- ✅ **详细反馈**：系统通知提供挂载状态反馈
- ✅ **错误处理**：完善的错误处理和日志记录
- ✅ **权限管理**：智能处理权限问题
- ✅ **图形化界面**：提供LaunchAgent配置文件

## 技术改进

- **模块化设计**：函数库分离，代码结构清晰
- **智能挂载逻辑**：服务器状态自动检测，服务就绪等待机制
- **安全性考虑**：配置文件权限管理，脚本权限检查
- **性能优化**：并行处理多服务器，智能缓存机制
- **用户体验**：系统通知，详细的错误提示

## 修复的问题

- 修复挂载点显示"Macintosh HD"的问题
- 修复FUSE挂载权限问题
- 修复服务器慢启动导致的挂载失败
- 修复挂载状态验证不准确的问题
- 修复自动启动配置问题

## 系统要求

- macOS 10.14或更高版本
- rclone 1.60.0或更高版本
- FUSE for macOS（可选）
- jq 1.6或更高版本

## 安装说明

1. 解压发布包到任意目录
2. 编辑 `config.json` 文件，修改服务器配置
3. 运行 `mount_webdav.sh` 脚本开始挂载
4. 按照 README.md 中的说明配置自动启动

## 故障排除

请参考 README.md 文件中的故障排除部分。
EOF

# 创建安装脚本
echo "创建安装脚本..."
cat > "$BUILD_DIR/install.sh" << 'EOF'
#!/bin/bash

# WebDAV自动挂载系统 - 安装脚本

echo "======================================="
echo "WebDAV自动挂载系统 - 安装脚本"
echo "======================================="

# 设置目标目录
TARGET_DIR="/Users/$USER/workspace/Rclone"

# 创建目标目录
if [ ! -d "$TARGET_DIR" ]; then
    echo "创建目标目录: $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
fi

# 复制文件
echo "复制文件到目标目录..."
cp -r ./* "$TARGET_DIR/"

# 设置执行权限
echo "设置执行权限..."
chmod +x "$TARGET_DIR/mount_webdav.sh"
chmod +x "$TARGET_DIR/lib/*.sh"

# 配置自动启动
echo ""
echo "======================================="
echo "配置自动启动"
echo "======================================="
echo "要配置自动启动，请执行以下命令："
echo ""
echo "1. 复制 LaunchAgent 配置文件："
echo "   cp $TARGET_DIR/com.rclone.automount-webdav.plist ~/Library/LaunchAgents/"
echo ""
echo "2. 加载配置："
echo "   launchctl load ~/Library/LaunchAgents/com.rclone.automount-webdav.plist"
echo ""
echo "3. 启动服务："
echo "   launchctl start com.rclone.automount-webdav"
echo ""
echo "======================================="
echo "安装完成！"
echo "======================================="
EOF

chmod +x "$BUILD_DIR/install.sh"

# 创建压缩包
echo "创建发布压缩包..."
if [ -f "$ZIP_FILE" ]; then
    rm "$ZIP_FILE"
fi

# 切换到发布目录并创建压缩包
cd "$RELEASE_DIR"
zip -r "$ZIP_FILE" "$PROJECT_NAME-$VERSION"

# 检查压缩包是否创建成功
if [ -f "$ZIP_FILE" ]; then
    echo ""
echo "======================================="
echo "发布打包完成！"
echo "======================================="
echo "版本: $VERSION"
echo "发布文件: $ZIP_FILE"
echo "文件大小: $(du -h "$ZIP_FILE" | cut -f1)"
echo "======================================="
echo ""
echo "发布包包含以下内容："
ls -la "$BUILD_DIR"
echo ""
else
    echo "错误：创建压缩包失败！"
    exit 1
fi

# 清理构建目录
echo "清理构建目录..."
rm -rf "$BUILD_DIR"

# 显示完成信息
echo "======================================="
echo "发布打包脚本执行完成！"
echo "======================================="
