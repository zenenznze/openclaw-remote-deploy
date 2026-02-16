# OpenClaw 远程一键部署工具

> **🔄 持续更新中** | 基于真实部署经验持续优化，确保与 OpenClaw 最新版本保持同步

OpenClaw 远程部署 Claude Code Skill（状态机 v4.7）— 30 分钟内完成含飞书/Telegram 集成的完整部署。

## ✨ 特性

- **🚀 一键部署**：自动化安装脚本，支持 Windows 和 Linux
- **📋 配置收集**：交互式配置向导，自动生成 OpenClaw 配置文件
- **🔌 多平台集成**：预配置飞书和 Telegram 集成模板
- **🎯 提供商注册表**：基于真实部署经验的模型提供商配置
- **📚 完整文档**：详细的部署指南和参考文档

## 📦 包含内容

### 安装脚本
- `install-openclaw.sh` - Linux/macOS 自动安装脚本
- `install-openclaw.ps1` - Windows PowerShell 安装脚本

### 配置工具
- `collect-config.sh` - Linux/macOS 配置收集脚本
- `collect-config.ps1` - Windows 配置收集脚本

### 配置模板
- `feishu-permissions.json` - 飞书应用完整权限配置
- `provider-registry.json` - 预验证的模型提供商配置

### 文档
- `SKILL.md` - Skill 使用指南
- `REFERENCE.md` - 详细参考文档
- `UPDATE-v4.5.md` - 版本更新说明

## 🚀 快速开始

### Linux/macOS

```bash
# 1. 下载安装脚本
curl -O https://raw.githubusercontent.com/zenenznze/openclaw-remote-deploy/main/install-openclaw.sh
chmod +x install-openclaw.sh

# 2. 运行安装
./install-openclaw.sh

# 3. 收集配置
./collect-config.sh
```

### Windows

```powershell
# 1. 下载安装脚本
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/zenenznze/openclaw-remote-deploy/main/install-openclaw.ps1" -OutFile "install-openclaw.ps1"

# 2. 运行安装
.\install-openclaw.ps1

# 3. 收集配置
.\collect-config.ps1
```

## 🔒 隐私与安全

### ✅ 安全保证

- **无硬编码密钥**：所有 API Key、Token、Secret 均通过用户输入获取，不在代码中硬编码
- **本地配置保护**：`.gitignore` 已配置排除 `.claude/` 本地配置目录
- **环境变量优先**：敏感信息通过环境变量传递，不写入版本控制

### 📋 已排除的敏感文件

```.gitignore
# Claude Code 本地配置
.claude/

# 操作系统文件
.DS_Store
Thumbs.db

# 临时文件
*.tmp
*.log
```

### 🔍 安全检查结果

经过全面检查，本仓库：
- ✅ 无硬编码 API Key
- ✅ 无硬编码 Token
- ✅ 无硬编码 Secret
- ✅ 无未脱敏的敏感信息

所有配置文件仅包含：
- 权限配置模板（无实际凭证）
- 提供商配置模板（使用环境变量占位符）
- 示例配置（无真实密钥）

## 📖 使用文档

详细使用说明请参考：
- [SKILL.md](./SKILL.md) - Skill 使用指南
- [REFERENCE.md](./REFERENCE.md) - 完整参考文档
- [UPDATE-v4.5.md](./UPDATE-v4.5.md) - 版本更新说明

## 🔄 持续更新

本项目基于真实部署经验**持续更新**，包括：
- ✨ 新功能和改进
- 🐛 Bug 修复
- 📚 文档完善
- 🔧 配置优化

建议定期拉取最新版本以获得最佳体验。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

## 🔗 相关链接

- [OpenClaw 官方文档](https://github.com/openclaw/openclaw)
- [Claude Code](https://github.com/anthropics/claude-code)

---

**⚠️ 注意**：使用前请确保已安装 Node.js 18+ 和 Git。
