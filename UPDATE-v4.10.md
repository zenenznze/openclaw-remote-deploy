# OpenClaw Remote Deploy v4.10 更新日志

**发布日期**: 2026-02-10

## 🔥 重要修正

### MiniMax 配置更新
- **只支持 MiniMax Coding Plan（免费版）**，不再支持付费版 API
- **原因**: MiniMax API 和 Coding Plan 使用完全不同的 API Key，容易混淆导致配置错误
- **正确配置**:
  - API 类型: `anthropic-messages`
  - baseUrl: `https://api.minimaxi.com/anthropic`
  - 模型 ID: `MiniMax-M2.1`

## 📋 基于实际部署经验的优化

本次更新基于两次真实部署的复盘（2026-02-10）：
- 第一次部署：53 分钟（macOS + MiniMax 国内版 + 飞书）
- 第二次部署：131 分钟（macOS + MiniMax Coding Plan + 钉钉）

## ✨ 新增功能

### 1. macOS 环境检查增强
- **Xcode 命令行工具检查**: 自动检测是否安装，未安装时提示执行 `xcode-select --install`
- **npm 权限检查**: 检测全局安装目录权限，避免 sudo 权限问题

### 2. npm 用户目录配置方案
提供无需 sudo 的安装方案：
```bash
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
export PATH=~/.npm-global/bin:$PATH
```

### 3. Gateway 配置默认值
- 配置模板默认包含 `gateway.mode: "local"`
- 避免启动失败错误："set gateway.mode=local"

### 4. 飞书配置优化
- **默认策略**: 使用 `open` 策略 + `allowFrom: ["*"]`（避免 pairing 策略导致的无回复问题）
- **自动启用插件**: 配置中包含 `plugins.entries.feishu.enabled: true`
- 用户无需手动执行 `openclaw plugins enable feishu`

## 🐛 故障处理增强

新增 10+ 个常见问题和解决方案：

| 问题 | 解决方案 |
|------|----------|
| Gateway 启动失败 "set gateway.mode=local" | 添加 `"mode": "local"` 到 gateway 配置 |
| npm 安装权限错误（macOS/Linux） | 配置 npm 使用用户目录 |
| Xcode 命令行工具缺失（macOS） | 执行 `xcode-select --install` |
| MiniMax Coding Plan 配置错误 | 使用 anthropic-messages + /anthropic 端点 |
| MiniMax API 返回 insufficient balance | 检查余额，确认使用正确的端点 |
| Provider in cooldown (rate_limit) | 重启 Gateway |
| 飞书插件状态为 disabled | 执行 `openclaw plugins enable feishu` |
| 飞书机器人无回复（pairing 策略） | 改为 open 策略 |
| 钉钉 open policy requires allowFrom | 添加 `"allowFrom": ["*"]` |

## 📝 文件更新

### provider-registry.json
- 移除 MiniMax API（付费版）配置
- 保留 MiniMax Coding Plan（免费版）配置
- 更新注释，明确说明不支持付费版

### SKILL.md
- Phase 0: 更新提供商列表，移除付费版选项
- Phase 1: 新增 macOS 环境检查和 npm 权限配置
- Phase 2: 配置模板默认包含 `gateway.mode: "local"`
- Phase 2: 飞书配置默认使用 open 策略 + 自动启用插件
- 故障处理速查: 新增 10+ 个问题和解决方案
- 版本信息: 更新到 v4.10

## 🎯 影响范围

- **破坏性变更**: 移除 MiniMax API（付费版）支持
- **建议**: 如果需要使用 MiniMax 付费版 API，请使用"自定义 OpenAI 兼容"选项手动配置

## 📊 部署时间优化

通过本次更新，预期可以减少以下问题导致的时间浪费：
- 权限问题：-20 分钟（通过 npm 用户目录配置）
- Gateway 配置缺失：-3 分钟（默认包含 mode 配置）
- 飞书插件启用：-2 分钟（自动启用）
- MiniMax 配置错误：-90 分钟（移除付费版，避免混淆）

**预期总耗时**: 30-40 分钟（含 IM 集成）

## 🙏 致谢

感谢两次实际部署中遇到的所有问题，它们帮助我们发现并修复了这些关键问题。
