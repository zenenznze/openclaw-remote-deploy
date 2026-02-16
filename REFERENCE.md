# OpenClaw 参考文档 (REFERENCE.md)

> 本文档合并了故障排查、飞书集成、安装指南的所有参考信息。
> 仅在遇到问题时查阅，正常部署流程请参考 SKILL.md。

---

## 第 1 章：故障排查快速索引

### 快速诊断命令
```bash
openclaw status              # 快速状态检查
openclaw status --deep       # 深度检查（包括模型探测）
openclaw models status       # 查看模型配置
openclaw gateway status      # Gateway 状态
openclaw security audit      # 安全审计
openclaw doctor              # 系统诊断
```

### 问题 1: Workspace 路径错误

**症状**: ENOENT, heartbeat failed, `no such file or directory, mkdir '/home/node'`

**原因**: 配置文件中路径不存在（可能用了 Docker 容器路径或其他 OS 路径）

**修复**:
```bash
# 编辑 ~/.openclaw/openclaw.json，使用正确的 OS 路径：
# macOS:   /Users/<username>/clawd
# Linux:   /home/<username>/clawd
# Windows: C:\\Users\\<username>\\clawd

# 创建工作目录
mkdir -p ~/clawd  # macOS/Linux

# 重启
openclaw gateway restart
```

### 问题 2: 插件重复加载

**症状**: `duplicate plugin id detected`, `Cannot find module 'zod'`

**修复**:
```bash
rm -rf ~/.openclaw/extensions/<plugin-name>
openclaw gateway restart
```

**最佳实践**: 使用全局安装的插件，不要在用户目录复制。

### 问题 3: 凭据目录权限过宽

**症状**: security audit WARN `Credentials dir is readable by others`

**修复**:
```bash
# macOS/Linux
chmod 700 ~/.openclaw/credentials

# Windows (PowerShell)
icacls "$env:USERPROFILE\.openclaw\credentials" /inheritance:r /grant:r "$env:USERNAME:(OI)(CI)F"
```

### 问题 4: Gateway 无法启动

**可能原因**: 端口占用、配置错误、权限问题

**修复**:
```bash
lsof -i :18789                          # macOS/Linux 检查端口
netstat -ano | findstr :18789           # Windows 检查端口
openclaw doctor
openclaw gateway restart
openclaw logs --follow                  # 查看日志
```



### 问题 6: 模型配置缺少 fallback

**症状**: 主模型不可用时服务中断

**修复**: 在 `agents.defaults.model` 中添加 `fallbacks` 数组，至少 1 个来自不同 provider。

### 问题 7: 飞书插件缺少 zod 模块

**症状**: 飞书 channel 启动失败，日志显示 `Cannot find module 'zod'`

**原因**: OpenClaw 内置了飞书插件，但飞书插件依赖的 zod 模块未内置

**修复**:
```bash
npm install -g zod
openclaw gateway restart
```

**验证**: `npm list -g zod` 应显示 zod 版本信息

### 问题 8: OAuth 模型不可见或无法使用

**症状**:
- 模型在 `openclaw models list` 中显示，但实际使用时失败
- 配置文件中有 `auth.profiles` 配置，但模型无法调用
- 错误信息提示认证失败或 token 无效

**原因**: OAuth token 已过期或凭据文件丢失

**诊断步骤**:
```bash
# 1. 检查配置文件中的 OAuth 配置
cat ~/.openclaw/openclaw.json | grep -A 5 '"auth"'

# 2. 检查凭据文件是否存在
ls -la ~/.openclaw/credentials/

# 3. 查看模型列表，确认 Auth 状态
openclaw models list
```

**修复**:
```bash
# 重新进行 OAuth 登录（以 openai-codex 为例）
openclaw models auth login --provider openai-codex

# 或使用交互式添加
openclaw models auth add

# 验证登录成功
openclaw models list  # 应该显示 Auth: yes
```

**预防措施**:
- OAuth token 通常有有效期（如 30-90 天），定期检查和更新
- 凭据文件位置：`~/.openclaw/credentials/<provider>-<profile>.json`


**相关命令**:
```bash
openclaw models auth login --help           # 查看登录帮助
openclaw models auth login --provider <id>  # 指定提供商登录
openclaw models auth add                    # 交互式添加认证
```

### 问题 8: 模型返回 "no output"

**症状**: 切换模型后，发送消息返回 "no output"

**原因**: 这不是配置失败！"no output" 的意思是输出在其他环境里了

**可能的输出位置**:
- Web 环境（http://127.0.0.1:18789/）
- 飞书机器人
- Telegram bot
- 其他已配置的 channels

**解决方法**:
1. 不要慌张，配置可能是成功的
2. 检查其他已配置的环境
3. 如果其他环境能看到输出，说明配置正确，只是输出位置不对
4. 可以在 TUI 中用 `/new` 命令开新窗口，再切换模型

### 问题 9: 代理干扰导致 LAN 连接失败（Ollama/自定义提供商）

**症状**: Connection error，usage 全部为 0，日志显示 agent 运行但无 API 调用

**诊断**:
```bash
# 检查是否有代理
env | grep -i proxy
# 直接测试连通性
curl -s http://192.168.1.82:11434/v1/models
# 绕过代理测试
NO_PROXY=* curl -s http://192.168.1.82:11434/v1/models
```

**根本原因**: OpenClaw 使用的 HTTP 客户端库（OpenAI SDK/axios）不尊重 NO_PROXY 环境变量。
在 openclaw.json env、LaunchAgent plist、.env 文件中设置 NO_PROXY 均无效。

**解决方案: SSH 隧道** ⭐
```bash
# 将远程 Ollama 端口映射到本地
ssh -f -N -L 11434:localhost:11434 user@192.168.1.82

# 验证隧道
curl -s http://127.0.0.1:11434/v1/models

# 修改 openclaw.json 中的 baseUrl
# 从: http://192.168.1.82:11434/v1
# 改为: http://127.0.0.1:11434/v1

# 重启 Gateway
openclaw gateway restart
```

**SSH 隧道持久化（macOS LaunchAgent）**:
```xml
<!-- ~/Library/LaunchAgents/com.ollama.tunnel.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ollama.tunnel</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/ssh</string>
        <string>-N</string>
        <string>-L</string>
        <string>11434:localhost:11434</string>
        <string>user@192.168.1.82</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/tmp/ollama-tunnel.err</string>
    <key>StandardOutPath</key>
    <string>/tmp/ollama-tunnel.out</string>
</dict>
</plist>
```

加载 LaunchAgent:
```bash
launchctl load ~/Library/LaunchAgents/com.ollama.tunnel.plist
launchctl start com.ollama.tunnel
```

**替代方案**:
- 在 Ollama 服务器上直接运行 OpenClaw
- 等待 OpenClaw 修复代理绕过问题（可提交 issue）

### 问题 10: Ollama 连接超时

**症状**: 请求超时，无响应

**可能原因**:
1. Ollama 未启动或未监听外部地址
2. 防火墙阻止了端口

**修复**:
```bash
# 在 Ollama 服务器上检查
OLLAMA_HOST=0.0.0.0 ollama serve  # 监听所有接口
# 或修改 systemd 配置
sudo systemctl edit ollama  # 添加 Environment="OLLAMA_HOST=0.0.0.0"

# 检查防火墙
sudo ufw allow 11434  # Ubuntu
sudo firewall-cmd --add-port=11434/tcp --permanent  # CentOS
```

### 问题 11: Windows Gateway 安装权限不足

**症状**: `openclaw gateway install` 失败，错误信息 `schtasks create failed: 错误: 拒绝访问`

**原因**: Windows 任务计划程序（schtasks）需要管理员权限

**解决方案 1: 直接启动（推荐，无需管理员权限）**
```powershell
# 方式 1: 使用 gateway.cmd
cd ~/.openclaw
.\gateway.cmd

# 方式 2: 在新窗口启动
powershell -Command "Start-Process powershell -ArgumentList '-NoExit', '-Command', 'cd C:\Users\<username>\.openclaw; .\gateway.cmd'"

# 验证启动
netstat -ano | findstr :18789
```

**解决方案 2: 以管理员权限安装服务**
```powershell
# 1. 右键点击 PowerShell 图标
# 2. 选择"以管理员身份运行"
# 3. 执行安装命令
openclaw gateway install

# 4. 启动服务
openclaw gateway start
# 或使用任务计划程序
schtasks /Run /TN "OpenClaw Gateway"
```

**两种方式对比**:
| 方式 | 优点 | 缺点 |
|------|------|------|
| 直接启动 | 无需管理员权限，立即可用 | 关闭窗口后停止，不会开机自启 |
| 安装为服务 | 开机自启动，后台运行 | 需要管理员权限 |


---

## 第 2 章：飞书集成详细指南

### 前置要求
- OpenClaw ≥ 2026.2.6-3（**官方原版**，NOT 中文版）
- Node.js ≥ 22
- 飞书企业账号

**重要**：如果已安装旧版本 OpenClaw，必须先升级到 ≥ 2026.2.6-3 才能使用飞书集成。

### 常见飞书问题

#### 中文版与飞书插件不兼容
**错误**: `TypeError: (0 , _pluginSdk.listFeishuAccountIds) is not a function`

**修复**:
```bash
npm uninstall -g @qingchencloud/openclaw-zh
npm install -g openclaw@latest
openclaw --version  # 确认 >= 2026.2.6-3
```

#### 飞书权限不足
**错误**: `机器人目前缺少一些权限...contact:contact.base:readonly`

**修复**: 使用 `feishu-permissions.json` 在飞书开放平台批量导入权限 → 创建新版本 → 发布

#### 群组消息只回复一次
**原因**: 默认需要 @mention

**修复**: 在 `openclaw.json` 添加群组配置：
```json
{
  "channels": {
    "feishu": {
      "groups": {
        "oc_群组ID": { "requireMention": false }
      }
    }
  }
}
```

获取群组 ID: `openclaw logs --follow | grep chat_id`

### 完整飞书部署流程
1. **升级 OpenClaw**：确保版本 ≥ 2026.2.6-3（`npm update -g openclaw`）
2. **配置 OpenClaw**：在 openclaw.json 中添加飞书 channels 配置
3. **重启 Gateway**：`openclaw gateway restart`（建立长连接）
4. **飞书开放平台配置**：
   - https://open.feishu.cn/app → 创建企业自建应用
   - 权限管理 → 批量导入 `feishu-permissions.json` 的 scopes（包含所有 IM 权限）
   - 添加应用能力 → 机器人
   - 事件订阅：长连接 + `im.message.receive_v1`（**必须在 OpenClaw 建立长连接后才能保存，而建立长连接首先需要成功配置到openclaw里，openclaw正常运行后，再去后台开启**）
   - 版本管理与发布 → 创建版本 → 发布
5. **验证连接**：`openclaw channels list`（应显示 Feishu: ON - OK）
6. **配对用户**：飞书发消息 → `openclaw pairing approve feishu <CODE>`

### DM 策略选项
- `pairing` — 配对模式（默认，需批准）
- `open` — 开放模式（`allowFrom: ["*"]`）
- `allowlist` — 白名单模式
- `disabled` — 禁用私聊

### Lark 国际版
在 `channels.feishu` 中添加 `"domain": "lark"`

---

## 第 3 章：模型提供商注意事项

### 配置层级优先级（从高到低）
1. Agent 级别: `~/.openclaw/agents/<agent>/agent/models.json`
2. 全局级别: `~/.openclaw/openclaw.json`
3. 环境变量

**建议**: 删除 agent 级别的 `models.json`，统一使用全局配置。

### 问题 11: `/models` 列出所有内置 provider（只想显示已配置的）

**现象**: 在聊天里输入 `/models`，出现大量内置 provider（openai/anthropic/...），但你只希望看到自己配置的那几个。

**原因**: 未设置 `agents.defaults.models` allowlist 时，OpenClaw 会把内置 catalog 也纳入可见范围。

**修复（推荐默认）**:

1) 在 `agents.defaults.models` 写入 allowlist（至少包含 primary + fallbacks）

2) 将 `models.mode` 设为 `replace`，避免旧的 `~/.openclaw/agents/<agentId>/agent/models.json` 残留合并进来

3) 重启：`openclaw gateway restart`

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "kimi/kimi-latest",
        "fallbacks": ["minimax/abab6.5s-chat"]
      },
      "models": {
        "kimi/kimi-latest": {},
        "minimax/abab6.5s-chat": {}
      }
    }
  },
  "models": {
    "mode": "replace"
  }
}
```

**注意**: CLI 的 `openclaw models list --all` 永远会输出完整 catalog（这是全量浏览模式），不代表配置没生效。

### 提供商踩坑记录

| 提供商 | API 格式 | 踩坑点 |
|--------|----------|--------|
| OpenRouter | openai-completions | 标准格式 |
| Volcengine | openai-completions | Node.js 22+ macOS 有兼容性问题 |
| Ollama | openai-completions | 代理环境必须用 SSH 隧道，baseUrl 用 localhost 不要用 LAN IP |

### 调试技巧
```bash
# 启用详细日志（在 openclaw.json 中添加）
{ "logging": { "level": "trace", "consoleLevel": "trace" } }

# 查看实时日志
openclaw logs --follow
```

---

## 第 4 章：常用命令速查

### Gateway 管理
```bash
openclaw gateway start | stop | restart | status | install
openclaw logs --follow
```

### 频道管理
```bash
openclaw channels list | add
openclaw channels remove feishu
```

### 配对管理
```bash
openclaw pairing list feishu [--approved]
openclaw pairing approve feishu <CODE>
openclaw pairing reject feishu <CODE>
```

### 诊断
```bash
openclaw doctor [--fix]
openclaw status --deep
openclaw security audit
```

---

## 第 5 章：重要文件位置

| 文件/目录 | 路径 | 用途 |
|-----------|------|------|
| 配置文件 | `~/.openclaw/openclaw.json` | 主配置 |
| 凭据目录 | `~/.openclaw/credentials/` | API 密钥 |
| 扩展目录 | `~/.openclaw/extensions/` | 用户插件 |
| Session | `~/.openclaw/agents/main/sessions/` | 会话历史 |
| Agent 模型 | `~/.openclaw/agents/<agent>/agent/models.json` | Agent 级别模型配置 |
| 日志 | `/tmp/openclaw/openclaw-YYYY-MM-DD.log` | 运行日志 |

---

## 第 6 章：更新日志

- **v4.5.0** (2026-02-09): 新增 Windows 部署经验：Gateway 启动权限问题、Rescue Dashboard Windows 兼容性修复（编码、lsof→netstat、systemctl）
- **v4.4.0** (2026-02-09): 补充"/models 只显示已配置 provider"的默认配置与排查方法（models.mode=replace + allowlist）
- **v4.3.0** (2026-02-08): 新增 Ollama 提供商，代理检测，SSH 隧道方案，LAN 连接故障排查
- **v4.0.0** (2026-02-08): 状态机重构，provider-registry，feishu-permissions，脚本精简，文档合并
- **v3.2.0** (2026-02-07): 飞书集成指南，fallback 配置提醒
- **v3.1.0** (2026-02-07): 生产级优化，Minimax API 故障排查
- **v3.0.0** (2026-02-07): Docker → npm，moltbot → openclaw
- **v2.0.0** (2026-01-30): 配置指南、故障排查、最佳实践
- **v1.0.0** (2026-01-30): 初始版本（Docker 部署）

---

## 参考资源

- [OpenClaw 官方文档](https://docs.openclaw.ai)
- [飞书频道配置](https://docs.openclaw.ai/channels/feishu)
- [Gateway 配置](https://docs.openclaw.ai/gateway/configuration)
- [飞书开放平台](https://open.feishu.cn/app)
- [Lark 开放平台](https://open.larksuite.com/app)
- [快速开始](https://macaron.im/blog/openclaw-quick-start)
- [GitHub](https://github.com/openclaw/openclaw)
