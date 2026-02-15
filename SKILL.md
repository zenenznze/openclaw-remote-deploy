---
name: openclaw-remote-deploy
description: OpenClaw 远程一键部署（状态机 v4.21）— 30 分钟内完成含飞书/Telegram/钉钉/WhatsApp/Discord 集成的完整部署，支持 Windows 双实例 SSH 桥接和跨系统配置迁移，包含代理 Fake IP 劫持问题排查
argument-hint: "[optional: windows/macos/linux]"
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, Task, AskUserQuestion
---

# OpenClaw Remote Deploy v4.21 — 状态机执行流程

> 核心原则：**一次性收集所有信息 → 连续自动执行**
> 时间预算：无 IM 13 min / 含飞书 30 min / 含 Telegram 18 min / 含钉钉 20 min / 含 WhatsApp 23 min / 含 Discord 15 min / 双实例 +15 min

## ⚠️ 新手常见卡点速览（部署前必读）

> 来源：社区高频问题总结（@0xValkyrie_ai 等），覆盖 90% 新手踩坑场景

| # | 卡点 | 一句话解决 |
|---|------|-----------|
| 1 | Node.js 环境混乱（brew/nvm 混用、新终端找不到命令） | 统一用 nvm 管理 Node，不要混用安装源 |
| 2 | CLI 命令敲进了 TUI 聊天框 | **命令在 shell，聊天在 TUI** — 配置/授权/审批命令必须在系统终端执行 |
| 3 | 模型"看得到但用不了" | 确认 API Key 有效且有余额，切模型用 CLI 指令不要在聊天框里切 |
| 4 | 429 限流报错 | OpenClaw 默认携带完整上下文 + 失败重试，新手建议先用消耗可控的模型 |
| 5 | 中转站模型不可用 | 中转站可能模型不全或权限受限，优先用官方 API；**永远不要明文泄露 API Key** |
| 6 | 代理/TUN 模式导致安装失败 | 安装前开启上网工具的 TUN 模式和系统代理，确保 npm 能访问国际网络 |
| 7 | Windows PowerShell 执行策略限制 | 管理员权限运行 `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine -Force` |

## 技能包文件

| 文件 | 用途 |
|------|------|
| `SKILL.md` | 执行流程（本文件） |
| `collect-config.sh` | 配置收集脚本 (macOS/Linux) — 仅供用户手动执行参考 |
| `collect-config.ps1` | 配置收集脚本 (Windows) — 仅供用户手动执行参考 |
| `provider-registry.json` | 预置模型提供商配置（已验证 provider + 自定义模板） |
| `PROVIDERS-REFERENCE.md` | OpenClaw 官方文档摘要（配置生成参考） |
| `feishu-permissions.json` | 飞书权限 JSON（可直接批量导入） |
| `install-openclaw.sh` | macOS/Linux 安装脚本 |
| `install-openclaw.ps1` | Windows 安装脚本 |
| `REFERENCE.md` | 合并参考文档（故障排查 + 飞书 + 安装指南） |

---

## Phase 0: 信息收集 (< 1 min) — AI 直接收集

**核心原则**：使用 `AskUserQuestion` 逐步收集配置，无需依赖交互式脚本。

**注意**：`collect-config.sh` 和 `collect-config.ps1` 脚本仅供用户手动执行参考，因为 Claude Code 的 Bash 工具不支持交互式输入（`read -p` / `Read-Host`）。

### 配置收集流程

#### 问题 1: 操作系统
- 首先尝试自动检测：
  ```bash
  # Windows: echo %OS%
  # macOS/Linux: uname -s
  ```
- 如果无法检测，使用 `AskUserQuestion` 询问：Windows / macOS / Linux

#### 问题 2: 模型提供商
读取 `provider-registry.json`，使用 `AskUserQuestion` 列出选项：
- **Kimi (Moonshot)** — anthropic-messages
- **Minimax Coding Plan（国内端点）** — anthropic-messages
  - 端点：https://api.minimaxi.com/anthropic
- **Minimax Coding Plan（国外端点）** — anthropic-messages
  - 端点：https://api.minimax.io/anthropic
- **阿里云千问（通义千问）** — anthropic-messages
  - 端点：https://dashscope.aliyuncs.com/apps/anthropic
  - 模型 ID：qwen3-max-2026-01-23
- **OpenRouter** — openai-completions
- **Volcengine (火山引擎)** — openai-completions
- **Ollama (本地/局域网)** — openai-completions ⚠️ 需额外网络检查
- **自定义中转站** — 需提供详细信息

**如果用户选择 Ollama**，额外收集：
- Ollama 服务器地址（默认 127.0.0.1:11434）
- 模型名称（如 qwen:7b, llama3:8b 等）

**如果用户选择自定义中转站**，进入问题 3。

#### 问题 3: 自定义中转站配置（仅当选择自定义时）
使用 `AskUserQuestion` 收集：
1. **中转站类型**：
   - OpenAI 兼容（使用 openai-completions API）
   - Anthropic 兼容（使用 anthropic-messages API）

2. **baseUrl**：
   - 格式示例：`https://your-proxy.com/v1`
   - 必须包含协议（http:// 或 https://）

3. **模型 ID**：
   - 示例：`claude-opus-4-6`, `gpt-4`, `custom-model-name`

4. **API Key**：
   - 用户提供的 API Key

#### 问题 4: API Key（预置提供商）
- 对应提供商的 API Key
- 如果是 Ollama，使用默认值 `ollama`（占位符）

#### 问题 5: Fallback 模型
使用 `AskUserQuestion` 询问：
- **是否需要备用模型？**（推荐配置）
- 如果是，选择提供商（可以与主模型相同或不同）
- 收集对应的 API Key（如果是新提供商）

#### 问题 5.5: 成本与限流提醒
在确认配置前，向用户说明：
- OpenClaw 默认携带较完整的上下文，加上失败重试，短时间内可能触发 API 速率限制（429 错误）
- **新手建议**：先用消耗可控的模型（如千问、Kimi 等国产模型），等使用习惯稳定后再上高配模型
- 如果使用中转站：中转站价格友好但可能存在模型不全、权限受限、行为不透明的问题。建议先保证稳定，再考虑成本优化
- **安全提醒**：永远不要在聊天框、公开场合明文泄露 API Key

#### 问题 6: IM 集成
使用 `AskUserQuestion` 询问：
- **是否需要 IM 集成？**
- 如果是，选择类型（可多选）：
  - **飞书**：App ID + App Secret（可以稍后在 Phase 4 提供）
  - **Telegram**：Bot Token（可以稍后在 Phase 4 提供）
  - **钉钉**：Corp ID + Client ID + Client Secret + Agent ID（可以稍后在 Phase 4 提供）
  - **WhatsApp**：个人账号或企业账号（可以稍后在 Phase 4 提供）
  - **Discord**：Bot Token（可以稍后在 Phase 4 提供）
  - **多个集成**：可以同时配置飞书、Telegram、钉钉、WhatsApp 和 Discord


### 配置验证和确认

**收集完毕后，打印配置摘要**：
```
═══════════════════════════════════════
  配置摘要
═══════════════════════════════════════
  操作系统:     <OS>
  主模型提供商: <provider>
  主模型端点:   <baseUrl>（如果是 MiniMax，标注国内/国外）
  主模型 ID:    <model-id>
  备用模型:     <是/否>
  飞书集成:     <是/否>
  Telegram 集成: <是/否>
  钉钉集成:     <是/否>
  WhatsApp 集成: <是/否>
═══════════════════════════════════════
```

**等待用户确认后，进入 Phase 1。**

---

## Phase 1: 环境 + 安装 + 升级 (5 min) — 全自动

### 1.1 检测环境
```bash
node --version    # 需要 ≥22
npm --version
# Windows: echo %OS%  |  macOS/Linux: uname -s
```

**macOS 特殊检查**：
```bash
# 检查 Xcode 命令行工具
xcode-select -p
# 如果返回错误，需要安装：xcode-select --install
```

**⚠️ Node.js 安装源冲突检测（macOS/Linux）**：
```bash
# 检查 Node 来源，避免 brew/nvm/系统包管理器混用
which node
which npm
# 如果 node 来自 /usr/local/bin（brew）而 nvm 也存在，会导致版本混乱
command -v nvm  # 检查 nvm 是否存在
brew list node 2>/dev/null  # 检查 brew 是否安装了 node
```

**如果检测到多个 Node 来源**（brew + nvm 混用）：
1. **推荐**：统一使用 nvm，卸载 brew 的 node
```bash
brew uninstall node
nvm install 22
nvm use 22
nvm alias default 22
```
2. 确认新终端也能正确加载 nvm：
```bash
# 检查 shell 配置文件是否包含 nvm 初始化
grep -l 'nvm' ~/.bashrc ~/.zshrc ~/.bash_profile 2>/dev/null
# 如果没有，需要添加 nvm 初始化脚本
```

**新终端找不到 node/openclaw 命令**：
- 原因：shell 配置文件未正确加载 nvm 或 PATH
- 修复：确保 `~/.zshrc`（macOS）或 `~/.bashrc`（Linux）包含正确的 PATH 和 nvm 初始化

**npm 权限检查（macOS/Linux）**：
```bash
# 检查 npm 全局安装目录权限
npm config get prefix
# 如果是 /usr/local，可能需要 sudo 权限
```

**如果检测到权限问题**，提供两种解决方案：
1. **推荐**：配置 npm 使用用户目录（无需 sudo）
```bash
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
export PATH=~/.npm-global/bin:$PATH
# 添加到 shell 配置文件
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc  # 或 ~/.zshrc
```

2. **备选**：使用 sudo 安装（需要用户手动输入密码）

### 1.2 检查 OpenClaw 安装状态
```bash
openclaw --version  # 检查是否已安装
```

**如果已安装**：
- 检查版本是否 ≥ 2026.2.6-3（飞书集成最低要求）
- 如果版本过低，执行升级：`npm update -g openclaw`
- 升级后验证：`openclaw --version`

**如果未安装**：
- **推荐方式**：直接使用 npm 全局安装
  ```bash
  npm install -g openclaw@latest
  ```
- **备选方式**：根据 OS 选择安装脚本（仅当 npm 安装失败时使用）
  - macOS/Linux: 读取 `install-openclaw.sh` → Bash 执行
  - Windows: 读取 `install-openclaw.ps1` → PowerShell 执行
- 脚本功能：环境检查 → 安装 → 目录创建 → 权限修复 → 启动

**Windows 特殊注意**：
- 必须以管理员权限运行 PowerShell
- 如果遇到执行策略限制，先运行：
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine -Force
  ```

### 1.3 安装 zod 模块（飞书必需）
```bash
npm install -g zod
```
**重要**：OpenClaw 飞书插件依赖 zod 模块，但未内置。必须手动安装。

### 1.4 验证安装
```bash
openclaw --version  # 确认版本 ≥ 2026.2.6-3
npm list -g zod     # 确认 zod 已安装
openclaw doctor     # 快速诊断
```

**失败处理**：读取 `REFERENCE.md` 第 1 章故障排查。

### 1.5 网络环境检测（Ollama/LAN 提供商时执行）

仅当用户选择了 Ollama 或自定义提供商且 baseUrl 为局域网 IP 时执行：

**检测代理**：
```bash
# macOS/Linux
env | grep -i proxy
# Windows
Get-ChildItem Env: | Where-Object { $_.Name -match 'proxy' }
```

**如果检测到代理 + 目标是 LAN IP**：
⚠️ 已知问题：OpenClaw 的 HTTP 客户端不尊重 NO_PROXY，LAN IP 请求会被路由到代理。

**解决方案：SSH 隧道**
```bash
ssh -f -N -L 11434:localhost:11434 <user>@<ollama-server-ip>
```
然后 baseUrl 使用 `http://127.0.0.1:11434/v1`（不要用 LAN IP）。

**如果无代理**：直接使用 LAN IP 的 baseUrl。

**连通性预检**：
```bash
curl -s http://<baseUrl>/v1/models | head -c 200
```
确认能连通后再进入 Phase 2。

---

## Phase 2: 配置生成 (3 min) — 全自动

### 2.1 读取 provider-registry.json
从注册表中获取用户选择的提供商配置。

### 2.2 组装完整 openclaw.json
用 Write 工具直接写入 `~/.openclaw/openclaw.json`：

```
路径:
  Windows: %USERPROFILE%\.openclaw\openclaw.json
  macOS/Linux: ~/.openclaw/openclaw.json
```

**配置结构**：
```json
{
  "env": { "<PROVIDER_API_KEY_VAR>": "<用户提供的 API Key>" },
  "gateway": {
    "bind": "loopback", "port": 18789,
    "mode": "local",
    "auth": { "token": "<自动生成 64 位 hex>" },
    "controlUi": { "allowInsecureAuth": false }
  },
  "agents": {
    "defaults": {
      "workspace": "<OS 对应路径>/clawd",
      "model": {
        "primary": "<provider>/<model-id>",
        "fallbacks": ["<fallback-provider>/<fallback-model>"]
      },
      "models": {
        "<provider>/<model-id>": {},
        "<fallback-provider>/<fallback-model>": {}
      }
    }
  },
  "models": {
    "mode": "replace",
    "providers": {
      "<provider-name>": {
        "baseUrl": "<从 registry 获取>",
        "api": "<从 registry 获取>",
        "apiKey": "${<ENV_VAR>}",
        "models": [<从 registry 获取>]
      }
    }
  }
}
```

**默认策略（只显示已配置的 provider）**：

- `agents.defaults.models` 不为空：它就是 allowlist，会直接影响 `/model` / `/models` 的可见范围（只展示你列出来的条目 + 当前默认/回退）。
- `models.mode: "replace"`：覆盖写入 agent 目录下的 `models.json`，避免历史残留 provider 被合并进来导致列表变长。

注意：CLI 的 `openclaw models list --all` 仍会列出完整内置 catalog（这是“全量浏览”模式，属于正常行为）。

### 2.3 如果用户选择了 IM 集成，追加 channels 配置

**飞书配置**：
```json
{
  "channels": {
    "feishu": {
      "enabled": true, "dmPolicy": "open",
      "allowFrom": ["*"],
      "accounts": {
        "main": { "appId": "<用户提供>", "appSecret": "<用户提供>", "botName": "OpenClaw AI" }
      }
    }
  },
  "plugins": {
    "entries": {
      "feishu": { "enabled": true }
    }
  }
}
```

**Telegram 配置**：
```json
{
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "<用户提供的 Bot Token>",
      "dmPolicy": "pairing"
    }
  }
}
```

**钉钉配置**：
```json
{
  "channels": {
    "dingtalk": {
      "enabled": true,
      "clientId": "<用户提供的 Client ID>",
      "clientSecret": "<用户提供的 Client Secret>",
      "robotCode": "<用户提供的 Client ID>",
      "corpId": "<用户提供的 Corp ID>",
      "agentId": "<用户提供的 Agent ID>",
      "dmPolicy": "open",
      "groupPolicy": "open",
      "messageType": "markdown",
      "debug": false
    }
  }
}
```

**WhatsApp 配置**：
```json
{
  "channels": {
    "whatsapp": {
      "selfChatMode": true,
      "dmPolicy": "pairing",
      "allowFrom": ["<用户手机号，如 +16573957180>"],
      "groupPolicy": "disabled",
      "ackReaction": {
        "emoji": "👀",
        "direct": true,
        "group": "never"
      }
    }
  },
  "plugins": {
    "entries": {
      "whatsapp": {
        "enabled": true
      }
    }
  }
}
```

**注意**：
- **个人账号**：必须设置 `selfChatMode: true`
- **推荐策略**：个人账号使用 `pairing`，企业账号可使用 `allowlist` 或 `open`
- **插件启用**：WhatsApp 插件默认为 disabled，必须在配置中启用或手动执行 `openclaw plugins enable whatsapp`

**Discord 配置**：
```json
{
  "channels": {
    "discord": {
      "enabled": true,
      "token": "<Bot Token>",
      "groupPolicy": "allowlist",
      "guilds": {
        "<服务器ID>": {
          "requireMention": true
        }
      },
      "dm": {
        "policy": "pairing"
      }
    }
  },
  "plugins": {
    "entries": {
      "discord": { "enabled": true }
    }
  }
}
```

**⚠️ Discord 群聊白名单机制（与其他 IM 不同）**：
- Discord 不使用 `allowFrom`（会报 `Unrecognized key` 错误）
- 必须使用 `guilds` 对象，以服务器 ID 为 key
- 每个 guild 可配置：`requireMention`（是否需要 @）、`users`（用户白名单）、`channels`（频道白名单）
- 如果 guild 没有 `channels` 块，该服务器所有频道都允许
- 获取服务器 ID：Discord 开发者模式 → 右键服务器 → 复制服务器 ID

**guilds 高级配置示例**：
```json
"guilds": {
  "123456789012345678": {
    "requireMention": true,
    "users": ["987654321098765432"],
    "channels": {
      "general": { "allow": true },
      "help": { "allow": true, "requireMention": true }
    }
  }
}
```

**同时配置多个**：
```json
{
  "channels": {
    "feishu": {
      "enabled": true, "dmPolicy": "pairing",
      "accounts": {
        "main": { "appId": "<用户提供>", "appSecret": "<用户提供>", "botName": "OpenClaw AI" }
      }
    },
    "telegram": {
      "enabled": true,
      "botToken": "<用户提供的 Bot Token>",
      "dmPolicy": "pairing"
    },
    "dingtalk": {
      "enabled": true,
      "clientId": "<用户提供的 Client ID>",
      "clientSecret": "<用户提供的 Client Secret>",
      "robotCode": "<用户提供的 Client ID>",
      "corpId": "<用户提供的 Corp ID>",
      "agentId": "<用户提供的 Agent ID>",
      "dmPolicy": "open",
      "groupPolicy": "open",
      "messageType": "markdown",
      "debug": false
    },
    "whatsapp": {
      "selfChatMode": true,
      "dmPolicy": "pairing",
      "allowFrom": ["<用户手机号>"],
      "groupPolicy": "disabled",
      "ackReaction": {
        "emoji": "👀",
        "direct": true,
        "group": "never"
      }
    },
    "discord": {
      "enabled": true,
      "token": "<Bot Token>",
      "groupPolicy": "allowlist",
      "guilds": {
        "<服务器ID>": { "requireMention": true }
      },
      "dm": { "policy": "pairing" }
    }
  },
  "plugins": {
    "entries": {
      "feishu": { "enabled": true },
      "whatsapp": { "enabled": true },
      "discord": { "enabled": true }
    }
  }
}
```

---

## Phase 3: 启动 + 验证 (2 min) — 全自动

### 3.1 重启 Gateway
```bash
openclaw gateway restart
sleep 5
```

### 3.2 快速验证
```bash
openclaw gateway status  # 验证 Gateway 运行状态
openclaw channels list   # 如果配置了 IM，验证 channel 状态
```

### 3.3 输出访问信息
```
访问地址: http://127.0.0.1:18789/
Auth Token: <显示 token>
```

### 3.4 CLI vs TUI 使用提醒
部署完成后，向用户说明：
```
⚠️ 重要区分：命令在 shell，聊天在 TUI
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 系统终端（shell）执行：
   - openclaw gateway restart
   - openclaw pairing approve ...
   - openclaw config set ...
   - openclaw models list
   - 所有 openclaw 开头的命令

✅ TUI 聊天框执行：
   - /model（切换模型）
   - /models（查看可用模型）
   - /new（新建会话）
   - 正常对话

❌ 不要在 TUI 聊天框里输入 shell 命令！
   TUI 会把它当成普通消息，不会执行。
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**如果不需要 IM 集成 → 跳到 Phase 5**

---

## Phase 4: IM 集成（飞书/Telegram）(15 min) — 半自动

### 4a: 飞书集成 (15 min)

#### 指导用户在飞书开放平台操作 (10 min)

输出精确的手动步骤指令：

1. **创建应用**：访问 https://open.feishu.cn/app → 创建企业自建应用
2. **配置权限**：权限管理 → 批量导入 → 粘贴 `feishu-permissions.json` 的 scopes 内容
3. **启用机器人**：添加应用能力 → 机器人
4. **事件订阅**：订阅方式选择「长连接」+ 添加事件 `im.message.receive_v1`
5. **发布应用**：版本管理与发布 → 创建版本 → 发布

#### 收到凭据后自动配置 (3 min)

如果 Phase 0 未收集 App ID/Secret，此时用 AskUserQuestion 收集。
用 Edit 工具更新 `~/.openclaw/openclaw.json` 的 channels 部分。

```bash
openclaw gateway restart
sleep 5
openclaw channels list  # 应显示 "Feishu main: configured, enabled"
```

#### 指导用户配对 (2 min)

1. 在飞书中找到 Bot，发送任意消息
2. Bot 回复配对码
3. 执行配对：
```bash
openclaw pairing list feishu
openclaw pairing approve feishu <配对码>
```

### 4b: Telegram 集成 (5 min)

#### 获取 Bot Token (2 min)

如果 Phase 0 未收集 Bot Token，指导用户获取：

1. 在 Telegram 中打开 [@BotFather](https://t.me/BotFather)
2. 发送 `/newbot` 命令
3. 按提示输入机器人名称和用户名（必须以 `bot` 结尾）
4. 复制返回的 Bot Token

#### 自动配置 (1 min)

用 Edit 工具更新 `~/.openclaw/openclaw.json` 的 channels 部分：

```json
"telegram": {
  "enabled": true,
  "botToken": "<用户提供的 Bot Token>",
  "dmPolicy": "pairing"
}
```

重启 Gateway：
```bash
openclaw gateway restart
sleep 5
openclaw channels list  # 应显示 "Telegram default: configured, enabled"
```

#### 指导用户配对 (2 min)

1. 在 Telegram 中找到你的 Bot（搜索 Bot 用户名）
2. 发送任意消息（如 "hello"）
3. Bot 回复配对码
4. 执行配对：
```bash
openclaw pairing list telegram
openclaw pairing approve telegram <配对码>
```

**配对成功后，用户就可以在 Telegram 中与 OpenClaw AI 对话了！**

### 4c: 钉钉集成 (20 min)

#### 指导用户在钉钉开放平台操作 (12 min)

输出精确的手动步骤指令：

**步骤 1：获取开发者权限**（2 种方式）

**方式 1：自己注册组织**
1. 访问钉钉官网教程：https://alidocs.dingtalk.com/i/p/Y7kmbokZp3pgGLq2/docs/3KLw95QMzkb8gDMZ3qaDWAjrymPeEN2q
2. 按照教程注册组织，获得管理员权限

**方式 2：联系现有组织管理员**
1. 联系你所在组织的管理员
2. 让管理员给你开通开发者权限
3. 参考文档：https://open.dingtalk.com/document/dingstart/get-developer-permissions

**步骤 2：创建机器人应用**
1. 打开钉钉开发者网页版：https://open-dev.dingtalk.com/
2. 扫码登录，选择你有管理员权限的组织
3. 确认主页显示你有开发者权限
4. 添加机器人：
   - 机器人简介和描述可以自定义
   - **重要**：消息接收方式必须选择「Stream」，保持默认，不要修改

**步骤 3：配置权限**
1. 在权限管理中搜索「卡片」
2. 将所有卡片相关权限全部打开

**步骤 4：发布版本**
1. 点击「版本管理与发布」
2. 创建新版本（版本号和版本描述自定义）
3. 保存后，**一定要在右边再点击「发布」按钮**

**步骤 5：获取配置参数**
在应用详情页面获取以下参数：
- **Corp ID**（企业 ID）
- **Client ID**（应用 ID）
- **Client Secret**（应用密钥）
- **Agent ID**（机器人 ID）

#### 安装钉钉插件 (3 min)

如果 Phase 0 未收集钉钉凭据，此时用 AskUserQuestion 收集：
- Corp ID
- Client ID
- Client Secret
- Agent ID

**安装插件（方法 A - 推荐）**：
```bash
openclaw plugins install https://github.com/soimy/clawdbot-channel-dingtalk.git
```

**如果方法 A 失败（spawn EINVAL 错误），使用方法 B - 手动安装**：
```bash
# 1. 手动克隆仓库到扩展目录
cd ~/.openclaw && mkdir -p extensions && cd extensions
git clone https://github.com/soimy/clawdbot-channel-dingtalk.git dingtalk

# 2. 安装依赖
cd dingtalk && npm install
```

**验证安装**：
```bash
openclaw plugins list | grep ding
# 应显示 "DingTalk Channel | dingtalk | loaded"
```

#### 配置钉钉插件 (3 min)

**重要**：每条命令执行后，检查回显最后一条信息是否为「Restart the gateway to apply.」，如果不是，说明参数设置不对，配置未成功。

逐条执行配置命令：
```bash
openclaw config set channels.dingtalk.enabled true
openclaw config set channels.dingtalk.clientId <用户提供的 Client ID>
openclaw config set channels.dingtalk.clientSecret <用户提供的 Client Secret>
openclaw config set channels.dingtalk.robotCode <用户提供的 Client ID>
openclaw config set channels.dingtalk.corpId <用户提供的 Corp ID>
openclaw config set channels.dingtalk.agentId <用户提供的 Agent ID>
openclaw config set channels.dingtalk.dmPolicy open
openclaw config set channels.dingtalk.groupPolicy open
openclaw config set channels.dingtalk.messageType markdown
openclaw config set channels.dingtalk.debug false
```

**重启 Gateway**：
```bash
openclaw gateway restart
sleep 5
openclaw channels list  # 应显示 "DingTalk: configured, enabled"
```

#### 测试钉钉机器人 (2 min)

1. 打开钉钉客户端
2. 点击搜索，输入你的机器人名字
3. 发送任意消息测试
4. 机器人应该能够正常响应

**注意**：钉钉机器人默认使用 `open` 策略（dmPolicy: open），无需配对即可使用。如果需要配对机制，可以将 dmPolicy 改为 `pairing`。

### 4d: WhatsApp 集成 (10 min)

#### 启用 WhatsApp 插件 (2 min)

**重要**：WhatsApp 插件默认为 disabled 状态，必须先启用。

```bash
openclaw plugins enable whatsapp
openclaw gateway restart
sleep 5
openclaw plugins list | grep whatsapp
# 应显示 "WhatsApp | whatsapp | loaded"
```

#### 配置 WhatsApp (3 min)

**询问用户账号类型**：
- 使用 AskUserQuestion 询问：个人账号 / 企业账号

**个人账号配置（推荐）**：
```bash
openclaw config set channels.whatsapp.selfChatMode true
openclaw config set channels.whatsapp.dmPolicy pairing
openclaw config set channels.whatsapp.groupPolicy disabled
openclaw config set channels.whatsapp.ackReaction.emoji "👀"
openclaw config set channels.whatsapp.ackReaction.direct true
openclaw config set channels.whatsapp.ackReaction.group never
```

**企业账号配置**：
```bash
openclaw config set channels.whatsapp.selfChatMode false
openclaw config set channels.whatsapp.dmPolicy allowlist
openclaw config set channels.whatsapp.groupPolicy open
openclaw config set channels.whatsapp.ackReaction.emoji "👀"
openclaw config set channels.whatsapp.ackReaction.direct true
openclaw config set channels.whatsapp.ackReaction.group always
```

**重启 Gateway**：
```bash
openclaw gateway restart
sleep 5
openclaw channels list  # 应显示 "WhatsApp default: not linked, enabled"
```

#### 登录 WhatsApp (3 min)

```bash
openclaw channels login
```

**选择 WhatsApp 渠道**，系统会生成 QR 码。

**指导用户扫码**：
1. 打开 WhatsApp 手机客户端
2. 点击「设置」→「已连接的设备」→「连接设备」
3. 扫描终端显示的 QR 码
4. 等待连接成功

**验证连接**：
```bash
openclaw channels status
# 应显示 "WhatsApp default: linked, enabled"
```

#### 测试 WhatsApp 机器人 (2 min)

**个人账号测试**：
1. 在 WhatsApp 中使用「Message yourself」功能（自聊）
2. 发送任意消息测试
3. 机器人应该能够正常响应

**企业账号测试**：
1. 让其他用户向企业账号发送消息
2. 如果使用 `pairing` 策略，用户会收到配对码
3. 执行配对：
```bash
openclaw pairing list whatsapp
openclaw pairing approve whatsapp <配对码>
```

**注意**：
- 个人账号必须设置 `selfChatMode: true`，否则无法使用自聊功能
- 个人账号推荐使用 `pairing` 策略，确保只有授权用户可以访问
- QR 码有效期约 20 秒，过期需要重新生成

### 4e: Discord 集成 (15 min)

#### 配置 Discord Bot Token (3 min)

**重要**：Discord 配置方式与其他 IM 不同，使用 `openclaw config set` 命令而不是直接编辑 JSON。

如果 Phase 0 未收集 Bot Token，此时用 AskUserQuestion 收集。

**配置命令**：
```bash
openclaw config set channels.discord.enabled true
openclaw config set channels.discord.token "<Bot Token>"
openclaw config set channels.discord.dm.policy pairing
openclaw config set channels.discord.groupPolicy allowlist
```

**配置群聊白名单（guilds）**：

⚠️ Discord 群聊白名单必须使用 `guilds` 对象，不能用 `allowFrom`（会报配置错误）。

使用 `AskUserQuestion` 收集用户的 Discord 服务器 ID，然后用 Edit 工具直接编辑 `~/.openclaw/openclaw.json`，在 `channels.discord` 中添加 `guilds` 块：

```json
"guilds": {
  "<服务器ID>": {
    "requireMention": true
  }
}
```

**获取服务器 ID 的方法**：
1. 打开 Discord 客户端
2. 进入「用户设置」→「高级」→ 打开「开发者模式」
3. 右键点击服务器图标 → 「复制服务器 ID」

**重要配置键名**（与其他 IM 不同）：
- ✅ `channels.discord.token`（不是 botToken）
- ✅ `channels.discord.dm.policy`（不是 dmPolicy）
- ✅ `channels.discord.groupPolicy`（不是 group.policy）
- ❌ `requireMention` 不是顶层配置，而是在 guild 级别

**重启 Gateway**：
```bash
openclaw gateway restart
sleep 5
openclaw channels status
```

#### Developer Portal 配置（必需）(5 min)

**指导用户在 Discord Developer Portal 操作**：

1. **访问 Developer Portal**：
   - URL: https://discord.com/developers/applications
   - 选择你的 Bot 应用

2. **启用 Privileged Gateway Intents**（必需）：
   - 进入 Bot 标签页
   - 启用以下 Intents：
     - ✅ **Message Content Intent**（必需）
     - ✅ **Server Members Intent**（推荐）
     - ✅ **Presence Intent**（可选）
   - 保存更改

3. **获取 Bot 授权链接**：
   - 进入 OAuth2 → URL Generator
   - 或使用以下格式：
   ```
   https://discord.com/oauth2/authorize?client_id=<BOT_ID>&permissions=506944&integration_type=0&scope=bot+applications.commands
   ```

**权限值说明**（506944 包含）：
- View Channels（查看频道）
- Send Messages（发送消息）
- Embed Links（嵌入链接）
- Attach Files（附加文件）
- Read Message History（读取消息历史）
- Add Reactions（添加反应）
- Use External Emojis（使用外部表情）
- Mention Everyone（提及所有人）
- Manage Messages（管理消息）

**最小权限配置**（367680）：
```
https://discord.com/oauth2/authorize?client_id=<BOT_ID>&permissions=367680&integration_type=0&scope=bot+applications.commands
```

#### 验证配置 (2 min)

```bash
openclaw gateway restart
sleep 5
openclaw channels status
# 预期: Discord default: enabled, configured, running
```

**常见状态**：
- `enabled, configured, running`：✅ 正常
- `enabled, configured, stopped`：❌ 需要检查 Intents
- `intents:content=disabled`：❌ Message Content Intent 未启用
- `error:Fatal Gateway error: 4014`：❌ Disallowed Intents

#### 测试 Discord Bot (2 min)

**私聊测试**（pairing 策略）：
1. 在 Discord 中搜索你的 Bot
2. 发送任意消息
3. Bot 回复配对码
4. 执行配对：
```bash
openclaw pairing list discord
openclaw pairing approve discord <配对码>
```
5. 再次发送消息测试

**服务器频道测试**（allowlist 策略）：
1. 将 Bot 添加到服务器（使用授权链接）
2. 在频道中 @提及 Bot：`@BotName 你好`
3. Bot 应该能够响应

**注意**：
- Discord 默认使用 `pairing` 策略（DM）
- 服务器频道默认使用 `allowlist` 策略
- 群组消息需要 @提及 Bot

#### 常见错误处理 (3 min)

**错误 4014：Disallowed Intents**
- **原因**：Message Content Intent 未在 Developer Portal 启用
- **解决**：访问 Bot 设置页面，启用 Message Content Intent，重启 Gateway

**intents:content=disabled**
- **原因**：同上
- **解决**：同上

**stopped 状态**
- **原因**：Token 错误或 Intents 问题
- **解决**：
  1. 检查 Token 是否正确：`openclaw config get channels.discord.token`
  2. 检查 Intents 是否启用
  3. 查看日志：`openclaw logs --follow | grep -i discord`

**配置键不识别**
- **原因**：使用了错误的键名（如 botToken、dmPolicy）
- **解决**：使用正确的键名（token、dm.policy）

**Bot 无权限**
- **原因**：授权链接权限值为 0
- **解决**：使用包含权限值的授权链接（推荐 506944）


---

## 配对机制详解

### 什么是配对？

**配对（Pairing）** 是 OpenClaw 的明确所有者批准步骤，用于控制谁可以访问你的 AI 助手。

### 配对策略

在 `channels.<channel>.dmPolicy` 中配置：

| 策略 | 说明 | 适用场景 |
|------|------|---------|
| `pairing` | 需要配对码验证（默认，推荐） | 个人使用，需要安全控制 |
| `allowlist` | 仅允许 `allowFrom` 列表中的用户 | 已知用户列表，无需每次配对 |
| `open` | 允许所有用户（需设置 `allowFrom: ["*"]`） | 公开服务，不推荐 |
| `disabled` | 禁用私聊 | 仅在群组中使用 |

### 配对流程详解

#### 1. 用户请求配对

- 未知用户首次发送消息时触发
- 系统生成 **8 字符大写配对码**（不含易混淆字符 `0O1I`）
- 配对码 **1 小时后过期**
- 每个频道默认最多 3 个待处理请求

#### 2. 查看待处理请求

```bash
# 查看飞书待处理请求
openclaw pairing list feishu

# 查看 Telegram 待处理请求
openclaw pairing list telegram
```

输出示例：
```
Pending pairing requests for telegram:
- Code: ABCD1234, From: @username (ID: 123456789), Requested: 5 minutes ago
```

#### 3. 批准或拒绝

```bash
# 批准配对
openclaw pairing approve telegram ABCD1234

# 配对码过期后，用户需要重新发送消息获取新码
```

**注意**：
- 配对码区分大小写
- 批准后，用户 ID 会被添加到 `~/.openclaw/credentials/<channel>-allowFrom.json`
- 批准是永久的，除非手动删除用户 ID

#### 4. 配对状态存储

配对信息存储在：
- 待处理请求：`~/.openclaw/credentials/<channel>-pairing.json`
- 已批准列表：`~/.openclaw/credentials/<channel>-allowFrom.json`

**安全提示**：这些文件包含敏感信息，应妥善保管。

### 配对限制

- 每个频道最多 3 个待处理请求
- 超出限制的请求会被忽略，直到有请求过期或被批准
- 配对码 1 小时后自动过期

### 跳过配对（不推荐）

如果你想跳过配对，可以使用 `allowlist` 或 `open` 策略：

**方式 1：预先添加用户 ID**
```json
"telegram": {
  "enabled": true,
  "botToken": "...",
  "dmPolicy": "allowlist",
  "allowFrom": ["123456789", "987654321"]
}
```

**方式 2：开放访问（不推荐）**
```json
"telegram": {
  "enabled": true,
  "botToken": "...",
  "dmPolicy": "open",
  "allowFrom": ["*"]
}
```

**获取用户 ID 的方法**：
1. 启动网关后查看日志：`openclaw logs --follow`，找到 `from.id`
2. 使用 Bot API：`curl "https://api.telegram.org/bot<token>/getUpdates"`
3. 向 @userinfobot 或 @getidsbot 发送消息

---

## Phase 5: 最终验证 (2 min) — 全自动

### 验证清单
```bash
openclaw --version          # ✓ 版本号 ≥ 2026.2.6-3
openclaw gateway status     # ✓ Gateway 运行中
openclaw channels list      # ✓ 如果有 IM：显示对应 channel 状态
```

### 输出部署摘要

```
═══════════════════════════════════════
  OpenClaw 部署完成！
═══════════════════════════════════════
  版本:     <version>
  地址:     http://127.0.0.1:18789/
  模型:     <provider>/<model>
  Fallback: <fallback-info>
  飞书:     <已配置/未配置>
  Telegram: <已配置/未配置>
  钉钉:     <已配置/未配置>
  WhatsApp: <已配置/未配置>
  Discord:  <已配置/未配置>
  Token:    <auth-token>
═══════════════════════════════════════
```

### 自动复盘与数据收集

**重要**：每次部署完成后，自动生成部署复盘报告，用于持续优化。

#### 耗时计算

在 Phase 0 开始时记录时间戳：
```bash
DEPLOY_START_TIME=$(date +%s)
PHASE0_START=$DEPLOY_START_TIME
```

在每个 Phase 结束时记录时间戳并计算耗时：
```bash
PHASE0_END=$(date +%s)
PHASE0_DURATION=$((PHASE0_END - PHASE0_START))

PHASE1_START=$(date +%s)
# ... Phase 1 操作 ...
PHASE1_END=$(date +%s)
PHASE1_DURATION=$((PHASE1_END - PHASE1_START))

# 以此类推...
```

计算总耗时：
```bash
DEPLOY_END_TIME=$(date +%s)
TOTAL_DURATION=$((DEPLOY_END_TIME - DEPLOY_START_TIME))
TOTAL_MINUTES=$((TOTAL_DURATION / 60))
```

#### 复盘报告生成

用 Write 工具创建复盘文件：`~/deployment-review-<timestamp>.md`

**文件位置**（用户根目录）：
- Windows: `C:\Users\<username>\deployment-review-<timestamp>.md`
- macOS/Linux: `~/deployment-review-<timestamp>.md`

**复盘内容**（脱敏处理）：
```markdown
# OpenClaw 部署复盘 - <ISO 8601 时间戳>

## 部署配置
- OS: <操作系统>
- OpenClaw 版本: <版本号>
- 主模型提供商: <provider>（脱敏：不记录 API Key）
- 主模型端点: <baseUrl>（如果是 MiniMax，标注国内/国外）
- 备用模型: <是/否>
- 飞书集成: <是/否>
- Telegram 集成: <是/否>
- 钉钉集成: <是/否>
- WhatsApp 集成: <是/否>

## 部署过程

### 时间线
- 部署开始: <ISO 8601 时间戳>
- Phase 0 (信息收集): <开始时间> - <结束时间> (耗时: <秒>s / <分钟>min)
- Phase 1 (环境与安装): <开始时间> - <结束时间> (耗时: <秒>s / <分钟>min)
- Phase 2 (配置生成): <开始时间> - <结束时间> (耗时: <秒>s / <分钟>min)
- Phase 3 (启动验证): <开始时间> - <结束时间> (耗时: <秒>s / <分钟>min)
- Phase 4 (IM 集成): <开始时间> - <结束时间> (耗时: <秒>s / <分钟>min)
- Phase 5 (最终验证): <开始时间> - <结束时间> (耗时: <秒>s / <分钟>min)
- 部署结束: <ISO 8601 时间戳>
- **总耗时**: <秒>s / <分钟>min

### 详细过程
- Phase 1 详情:
  - 是否需要升级: <是/否>
  - 是否需要安装 zod: <是/否>
- Phase 4 详情（如果有 IM 集成）:
  - 飞书: <耗时>
  - Telegram: <耗时>
  - 钉钉: <耗时>

## 遇到的问题
[列出所有遇到的错误和解决方法]

## 优化建议
[基于本次部署经验的改进建议]

## 验证结果
- Gateway 状态: <运行中/失败>
- 模型测试: <成功/失败>
- 飞书连接: <成功/失败/未配置>
- Telegram 连接: <成功/失败/未配置>
- 钉钉连接: <成功/失败/未配置>
- WhatsApp 连接: <成功/失败/未配置>

## 隐私保护声明
本报告已进行脱敏处理：
- ✅ 记录: OS、版本、提供商名称、端点、耗时、问题、解决方案
- ❌ 不记录: API Key 完整内容、Auth Token、App Secret 完整内容
```

**时间戳格式**：使用 ISO 8601 格式（如 `2026-02-10T15:30:45+08:00`）

---

## Phase 6: 部署后操作（可选）

### 6.1 切换默认模型

**适用场景**：
- 已经部署完成，想切换到另一个已配置的模型
- 想调整 fallback 模型的优先级
- 想在多个提供商之间切换

**⚠️ 模型切换常见坑**：
- **"看得到但用不了"**：模型在列表里显示，但缺少有效的 API Key 或授权，请求会失败。切换前务必确认目标模型的 API Key 有效且有余额
- **新 session 继承旧配置**：切换模型后，已有的 session 可能仍使用旧模型。建议用 `/new` 开新会话
- **切模型用 CLI 指令**：在 TUI 中用 `/model` 命令切换，不要在聊天框里让 AI "帮你切模型"（AI 无法修改运行时配置）

**操作流程**：

1. **读取当前配置**
```bash
Read ~/.openclaw/openclaw.json
```

2. **检查目标模型是否已配置**
   - 检查 `models.providers` 中是否有对应的提供商（API Key 方式）
   - 或检查 `auth.profiles` 中是否有 OAuth 配置（OAuth 方式）
   - 如果都没有，需要先添加提供商配置（见 6.2）

3. **询问用户配置方式**（如果目标提供商未在 `models.providers` 中）
   - 使用 AskUserQuestion 询问：
     - 使用现有 OAuth 认证（如果 `auth.profiles` 中有）
     - 添加 API Key 配置
     - 添加自定义 baseUrl + API Key

4. **修改配置文件**
   使用 Edit 工具修改 `~/.openclaw/openclaw.json`：
   - 将 `agents.defaults.model.primary` 改为目标模型
   - 调整 `agents.defaults.model.fallbacks` 顺序（原主模型可以降级为 fallback）
   - 确保 `agents.defaults.models` 中包含目标模型

5. **重启 Gateway**
```bash
openclaw gateway restart
sleep 5
```

6. **验证配置生效**
```bash
openclaw gateway status  # 确认 Gateway 运行中
openclaw models list     # 确认目标模型显示为 default
```

**示例**：
```json
// 修改前
"model": {
  "primary": "minimax/abab6.5s-chat",
  "fallbacks": ["custom-anthropic/claude-sonnet-4-5-20250929", "openai-codex/gpt-5.3-codex"]
}

// 修改后
"model": {
  "primary": "openai-codex/gpt-5.3-codex",
  "fallbacks": ["minimax/abab6.5s-chat", "custom-anthropic/claude-sonnet-4-5-20250929"]
}
```

**注意事项**：
- OAuth 提供商：只需要 `auth.profiles` 配置，不需要在 `models.providers` 中配置
- API Key 提供商：必须在 `models.providers` 中配置 baseUrl、api、apiKey 等
- 切换后，原主模型会自动变为 fallback（如果在 fallbacks 列表中）
- 如果目标模型不在 `agents.defaults.models` 中，需要添加（否则可能不可见）
- **OAuth token 过期问题**：如果 OAuth 模型在列表中显示但无法使用，可能是 token 过期。检查 `~/.openclaw/credentials/` 目录是否有对应的凭据文件（如 `openai-codex-default.json`）。如果缺失或过期，运行 `openclaw models auth login --provider <provider-id>` 重新登录

### 6.2 添加新的提供商

**适用场景**：
- 想添加一个全新的模型提供商
- 想配置多个提供商以便切换

**操作流程**：

1. **读取 provider-registry.json**
```bash
Read ~/.claude/skills/openclaw-remote-deploy/provider-registry.json
```

2. **选择提供商类型**
   - 使用 AskUserQuestion 让用户选择：
     - 预置提供商（Kimi、Minimax、OpenRouter、Volcengine、Ollama）
     - 自定义 OpenAI 兼容
     - 自定义 Anthropic 兼容

3. **收集配置信息**
   - API Key
   - baseUrl（如果是自定义提供商）
   - 模型 ID

4. **更新配置文件**
   使用 Edit 工具在 `~/.openclaw/openclaw.json` 中：
   - 在 `env` 中添加 API Key 环境变量
   - 在 `models.providers` 中添加新提供商配置
   - 在 `agents.defaults.models` 中添加新模型（可选，如果想立即使用）

5. **重启 Gateway 并验证**
```bash
openclaw gateway restart
sleep 5
openclaw models list --all  # 查看所有可用模型
```

### 6.3 修改 Fallback 配置

**适用场景**：
- 想添加或删除 fallback 模型
- 想调整 fallback 的优先级

**操作流程**：

1. 读取配置：`Read ~/.openclaw/openclaw.json`
2. 使用 Edit 工具修改 `agents.defaults.model.fallbacks` 数组
3. 确保所有 fallback 模型都在 `agents.defaults.models` 中
4. 重启 Gateway：`openclaw gateway restart`
5. 验证：`openclaw models list`

**最佳实践**：
- 建议至少配置 1 个 fallback 模型（提高可用性）
- Fallback 模型应该使用不同的提供商（避免单点故障）
- 按优先级排序：最优先的 fallback 放在数组第一位

### 6.4 Windows 双实例部署（Docker + SSH 桥接）

**适用场景**：
- 在同一台 Windows 机器上运行两个 OpenClaw 实例
- 主实例（Windows 本地）+ 配置管理实例（Docker 容器）
- 容器实例需要执行 Windows 宿主机命令（如 `openclaw gateway restart`）

**架构概览**：
```
┌─────────────────────────────────────────────┐
│  Windows 宿主机                              │
│  ├── 主实例（端口 18789）                     │
│  ├── OpenSSH Server（端口 22）                │
│  │                                           │
│  │  ┌─────────────────────────────────┐      │
│  │  │  Docker 容器（WSL2）             │      │
│  │  │  ├── 配置实例（端口 18790）       │      │
│  │  │  │                               │      │
│  │  │  │  ssh joe@host.docker.internal │      │
│  │  │  │  ──────────────────────────►  │      │
│  │  │  └───────────────────────────────┘      │
│  └───────────────────────────────────────────┘
```

**⚠️ docker-compose.yml 端口配置最佳实践**：

不要用 `.env` 变量引用端口和路径 — `docker compose` 在某些版本/环境下会解析失败（已知 bug：`.env` 中的变量被忽略或被同名系统环境变量覆盖）。直接在 `docker-compose.yml` 中硬编码：

```yaml
# ✅ 推荐：硬编码端口和路径
ports:
  - "18790:18789"    # 宿主 18790 → 容器 gateway 18789
  - "18791:18790"    # 宿主 18791 → 容器 bridge 18790
volumes:
  - ./docker-data/config:/home/node/.openclaw
  - ./docker-data/workspace-82:/home/node/.openclaw/workspace-82

# ❌ 避免：.env 变量引用（可能解析失败）
ports:
  - "${OPENCLAW_GATEWAY_PORT}:18789"
  - "${OPENCLAW_BRIDGE_PORT}:18790"
volumes:
  - ${OPENCLAW_CONFIG_DIR}:/home/node/.openclaw
  - ${OPENCLAW_WORKSPACE_DIR}:/home/node/.openclaw/workspace-82
```

**注意**：`image` 和 `OPENCLAW_GATEWAY_TOKEN` 等敏感值仍可保留在 `.env` 中（这些不容易出问题）。端口和路径是最容易踩坑的。

**⚠️ 已验证失败的跨环境方案（不要再试）**：

| 方案 | 失败原因 |
|------|---------|
| nsenter 黑魔法 | 只能进 WSL2 命名空间，碰不到 Windows |
| PowerShell HTTP Listener | 端口占用 + Windows 服务环境权限问题 |
| Python Flask + Windows 服务 | 防火墙/套接字权限问题 |

**最终方案：SSH 免密连接**

#### 步骤 1：安装 Windows OpenSSH Server

**推荐 MSI 独立版本**（比 Windows 内置功能更稳定）：
- 下载：https://github.com/PowerShell/Win32-OpenSSH/releases
- 安装 MSI 后，MSI 版本**不会自动注册服务**，需要手动注册

在管理员 PowerShell 中执行：
```powershell
# 注册服务（MSI 版本必须手动）
sc.exe create sshd binPath="C:\Program Files\OpenSSH\sshd.exe" start=auto DisplayName="OpenSSH SSH Server"

# 启动服务
Start-Service sshd

# 验证
Get-Service sshd
netstat -an | Select-String ':22 '
```

**⚠️ 踩坑**：`sshd.exe install` 在 MSI 版本中不支持，必须用 `sc.exe create`。

#### 步骤 2：在 Docker 容器内生成 SSH 密钥

```bash
docker exec <容器名> bash -c "mkdir -p ~/.ssh && ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_host -N '' -q"
docker exec <容器名> bash -c "cat ~/.ssh/id_ed25519_host.pub"
```

**⚠️ 踩坑**：容器内用户可能是 `node`（`/home/node/`）而不是 `root`，`~` 会解析到对应用户的 home 目录。

#### 步骤 3：配置 Windows 公钥认证

**⚠️ 关键踩坑：管理员用户的 authorized_keys 路径特殊**

Windows OpenSSH 的 `sshd_config` 末尾有：
```
Match Group administrators
       AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
```

这意味着管理员用户的公钥**不是**放在 `~/.ssh/authorized_keys`，而是 `C:\ProgramData\ssh\administrators_authorized_keys`。

**安全写入公钥的方法**（避免换行问题）：

```bash
# 1. 从容器导出公钥到 Windows 临时文件
docker exec <容器名> bash -c "cat ~/.ssh/id_ed25519_host.pub" > C:\Users\<用户名>\container_ssh_pubkey.txt
```

然后在管理员 PowerShell 中：
```powershell
# 2. 复制到正确位置
Copy-Item "C:\Users\<用户名>\container_ssh_pubkey.txt" "C:\ProgramData\ssh\administrators_authorized_keys" -Force

# 3. 修复权限（必须严格，否则 sshd 拒绝读取）
icacls "C:\ProgramData\ssh\administrators_authorized_keys" /inheritance:r /grant "SYSTEM:(F)" /grant "BUILTIN\Administrators:(F)"
```

**⚠️ 踩坑**：不要用 PowerShell 的 `Set-Content` 直接写公钥 — 如果命令跨行，公钥会被换行符拆成两行，导致认证永远失败。用临时文件 + `Copy-Item` 最安全。

#### 步骤 4：验证 SSH 连接

```bash
docker exec <容器名> bash -c "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i ~/.ssh/id_ed25519_host <用户名>@host.docker.internal 'echo SSH_OK'"
```

#### 步骤 5：测试跨环境命令执行

```bash
# 查看主实例状态
docker exec <容器名> bash -c "ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519_host <用户名>@host.docker.internal 'openclaw gateway status'"

# 重启主实例 Gateway
docker exec <容器名> bash -c "ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519_host <用户名>@host.docker.internal 'openclaw gateway restart'"
```

#### 踩坑总结

| # | 坑 | 解决方案 |
|---|-----|---------|
| 1 | 管理员用户 authorized_keys 路径不是 `~/.ssh/` | 放到 `C:\ProgramData\ssh\administrators_authorized_keys` |
| 2 | authorized_keys 权限不对导致认证失败 | `icacls /inheritance:r /grant "SYSTEM:(F)" /grant "BUILTIN\Administrators:(F)"` |
| 3 | PowerShell Set-Content 把公钥换行 | 用临时文件 + Copy-Item |
| 4 | MSI 版 OpenSSH 不自动注册服务 | `sc.exe create sshd binPath=...` |
| 5 | 容器内用户不是 root | 检查 `~` 实际解析路径，确认密钥位置 |
| 6 | host.docker.internal 解析为 IPv6 | 正常行为，SSH 能正常连接 |
| 7 | docker-compose.yml 中 .env 变量解析失败导致端口冲突 | 端口和路径直接硬编码在 compose 文件中，不用 .env 变量 |

---

## Phase 7: 配置迁移（跨系统/跨环境）

**适用场景**：
- 从 Windows 迁移到 Linux/macOS
- 从 Linux 迁移到 macOS 或反向
- 从一台机器迁移到另一台机器
- 备份恢复

### 7.1 迁移前检查

**源系统检查**：
```bash
# 检查 OpenClaw 版本
openclaw --version

# 检查配置文件位置
ls -la ~/.openclaw/openclaw.json

# 检查凭据目录
ls -la ~/.openclaw/credentials/

# 检查已配置的渠道
openclaw channels list

# 检查已配置的模型
openclaw models list
```

**目标系统检查**：
```bash
# 检查 Node.js 版本（需要 ≥22）
node --version

# 检查是否已安装 OpenClaw
openclaw --version 2>&1 || echo "未安装"
```

### 7.2 配置迁移流程

#### 步骤 1：复制配置目录

**从 Windows 到 Linux/macOS**：
```bash
# 假设 Windows 分区挂载在 /media/joe/Windows-SSD
cp -r "/media/joe/Windows-SSD/Users/<username>/.openclaw" ~/.openclaw
```

**从 Linux/macOS 到另一台 Linux/macOS**：
```bash
# 使用 rsync（推荐）
rsync -av --exclude='*.log' source-machine:~/.openclaw/ ~/.openclaw/

# 或使用 scp
scp -r source-machine:~/.openclaw ~/.openclaw
```

**从备份恢复**：
```bash
cp -r /path/to/backup/.openclaw ~/.openclaw
```

#### 步骤 2：更新路径配置

**关键配置项需要更新**：
1. `agents.defaults.workspace` - 工作空间路径
2. 检查是否有其他绝对路径引用

**使用 Edit 工具更新 workspace 路径**：
```json
// Windows 格式
"workspace": "C:\\Users\\joe\\clawd"

// Linux/macOS 格式
"workspace": "/home/joe/clawd"
```

**创建工作空间目录**：
```bash
mkdir -p ~/clawd  # 或配置中指定的路径
```

#### 步骤 3：修复文件权限（Linux/macOS）

```bash
# 设置正确的权限
chmod 700 ~/.openclaw
chmod 600 ~/.openclaw/openclaw.json
chmod 700 ~/.openclaw/credentials
chmod 600 ~/.openclaw/credentials/*
```

#### 步骤 4：安装 OpenClaw（如果未安装）

```bash
# 安装 OpenClaw
npm install -g openclaw

# 安装 zod（飞书必需）
npm install -g zod

# 验证安装
openclaw --version
```

#### 步骤 5：验证配置

**读取配置文件，检查关键配置**：
```bash
# 检查配置文件语法
cat ~/.openclaw/openclaw.json | jq . > /dev/null && echo "配置文件语法正确"

# 检查模型配置
openclaw models list

# 检查渠道配置
openclaw channels list
```

#### 步骤 6：启动 Gateway

```bash
# 启动 Gateway
openclaw gateway &

# 等待启动
sleep 5

# 验证状态
openclaw gateway status
openclaw channels list
```

### 7.3 迁移后常见问题

#### 问题 1：API 密钥失效（HTTP 401）

**症状**：
```
lane task error: error="FailoverError: HTTP 401: Invalid API key"
```

**原因**：
- 中转站服务商可能有 IP 限制
- API 密钥可能绑定到特定机器或账号
- 网络环境变化导致无法访问

**解决方案**：

**选项 A：更新 API 密钥**
```bash
openclaw config set env.<PROVIDER>_API_KEY "新的密钥"
openclaw gateway restart
```

**选项 B：切换到其他提供商**
- 如果原提供商不可用，配置新的提供商
- 更新 `agents.defaults.model.primary` 和 `fallbacks`

**选项 C：依赖 fallback 模型**
- 如果有 OAuth 提供商（如 openai-codex）作为 fallback，系统仍可正常工作
- 但每次请求会先尝试失败的提供商，增加延迟

#### 问题 2：OAuth 凭据丢失

**症状**：
```
OAuth 模型不可见/无法使用
```

**解决方案**：
```bash
# 重新登录 OAuth 提供商
openclaw models auth login --provider openai-codex
```

#### 问题 3：IM 渠道连接失败

**症状**：
- Telegram/Discord/飞书/钉钉无法连接
- Bot Token 或 App Secret 失效

**解决方案**：
1. 检查 Bot Token/App Secret 是否正确复制
2. 检查网络连接（特别是 Telegram 需要访问国际网络）
3. 重新配置渠道凭据

#### 问题 4：配置热重载失败

**症状**：
```
config change detected; evaluating reload
```
但配置未生效

**解决方案**：
```bash
# 完全重启 Gateway
pkill -f "openclaw gateway"
openclaw gateway &
```

### 7.4 迁移验证清单

**必须验证的项目**：
- [ ] Gateway 启动成功（`openclaw gateway status`）
- [ ] 至少一个模型可用（`openclaw models list`）
- [ ] 所有 IM 渠道已连接（`openclaw channels list`）
- [ ] 工作空间目录存在且可写
- [ ] 文件权限正确（700/600）
- [ ] 日志文件正常写入（`tail -f /tmp/openclaw/*.log`）

**可选验证**：
- [ ] 测试模型调用（通过 Web UI 或 TUI）
- [ ] 测试 IM 渠道消息收发
- [ ] 测试配对机制（如果使用 pairing 策略）

### 7.5 迁移最佳实践

1. **迁移前备份**：
   ```bash
   tar -czf openclaw-backup-$(date +%Y%m%d).tar.gz ~/.openclaw
   ```

2. **分阶段迁移**：
   - 先迁移配置文件，验证 Gateway 启动
   - 再测试模型可用性
   - 最后测试 IM 渠道

3. **保留源系统配置**：
   - 迁移成功前不要删除源系统配置
   - 可以同时运行两个实例（不同端口）

4. **记录迁移过程**：
   - 记录遇到的问题和解决方案
   - 生成迁移报告（参考 Phase 5 的复盘报告）

5. **API 密钥可移植性**：
   - **官方 API**（Anthropic、OpenAI）：通常可移植
   - **中转站 API**：可能有 IP 限制或设备绑定，迁移后可能失效
   - **OAuth 凭据**：需要重新登录

---

## 故障处理速查

| 症状 | 原因 | 快速修复 |
|------|------|----------|
| Gateway 启动失败 \"set gateway.mode=local\" | 配置缺少 gateway.mode | 在 openclaw.json 的 gateway 配置中添加 `"mode": "local"` |
| npm 安装权限错误（macOS/Linux） | 无法写入 /usr/local | 配置 npm 使用用户目录：`mkdir -p ~/.npm-global && npm config set prefix '~/.npm-global' && export PATH=~/.npm-global/bin:$PATH` |
| Xcode 命令行工具缺失（macOS） | npm 安装时报错 gyp | 执行 `xcode-select --install` |
| MiniMax Coding Plan 配置错误 | 使用了错误的端点/API 类型 | 使用 anthropic-messages + https://api.minimaxi.com/anthropic + 模型 ID: MiniMax-M2.1 |
| MiniMax API 返回 insufficient balance | 余额不足或配置错误 | 检查余额，确认使用正确的端点（付费版用 /v1，Coding Plan 用 /anthropic） |
| Provider in cooldown (rate_limit) | API 返回错误后进入冷却 | 重启 Gateway：`openclaw gateway restart` |
| 飞书插件状态为 disabled | 插件未启用 | 执行 `openclaw plugins enable feishu` 或在配置中添加 `plugins.entries.feishu.enabled: true` |
| 飞书机器人无回复（pairing 策略） | pairing 策略可能阻止首次回复 | 改为 open 策略：`dmPolicy: "open"` + `allowFrom: ["*"]` |
| ENOENT workspace | 路径错误 | 检查 OS 路径格式 |
| 401/403 API 错误 | API 格式/URL 错误 | 对照 provider-registry.json |
| duplicate plugin | 扩展目录冲突 | `rm -rf ~/.openclaw/extensions/<name>` |
| 权限 755 | credentials 权限过宽 | `chmod 700 ~/.openclaw/credentials` |
| OAuth 模型不可见/无法使用 | OAuth token 过期或丢失 | `openclaw models auth login --provider <provider-id>` 重新登录 |
| 飞书 TypeError | 使用了中文版 | 卸载中文版，安装官方版 |
| 飞书权限不足 | 缺少 IM 权限 | 用 feishu-permissions.json 重新导入 |
| 飞书 Cannot find module 'zod' | 缺少 zod 模块 | `npm install -g zod` |
| Telegram 不响应 | Bot Token 错误 | 检查 Token 格式，重新从 @BotFather 获取 |
| Telegram 配对失败 | 配对码过期 | 配对码 1 小时有效，重新发送消息获取新码 |
| Telegram 连接失败 | 无法访问 api.telegram.org | 检查网络/防火墙/DNS，或配置代理 |
| 钉钉插件安装失败（spawn EINVAL） | openclaw plugins install 命令错误 | 手动克隆：`cd ~/.openclaw/extensions && git clone https://github.com/soimy/clawdbot-channel-dingtalk.git dingtalk && cd dingtalk && npm install` |
| 钉钉配置不生效 | 配置命令回显不正确 | 检查每条命令回显是否为「Restart the gateway to apply.」 |
| 钉钉机器人不响应 | 参数配置错误 | 检查 Corp ID、Client ID、Client Secret、Agent ID 是否正确 |
| 钉钉权限不足 | 缺少卡片权限 | 在钉钉开放平台权限管理中搜索「卡片」，全部打开 |
| 钉钉消息接收方式错误 | 未选择 Stream 模式 | 在钉钉开放平台将消息接收方式改为「Stream」 |
| 钉钉 open policy requires allowFrom | 缺少 allowFrom 配置 | 在配置中添加 `"allowFrom": ["*"]` |
| WhatsApp 插件未启用 | 插件默认为 disabled | 执行 `openclaw plugins enable whatsapp` 并重启 Gateway |
| WhatsApp 个人账号无法自聊 | 未设置 selfChatMode | 在配置中添加 `"selfChatMode": true` |
| WhatsApp 配对失败 | 使用了 allowlist 策略 | 个人账号推荐使用 `"dmPolicy": "pairing"` |
| WhatsApp QR 码过期 | QR 码有效期约 20 秒 | 重新执行 `openclaw channels login` 生成新 QR 码 |
| WhatsApp 连接失败 | 手机未扫码或网络问题 | 确认手机已扫码，检查网络连接 |
| Discord 群聊被 @ 不响应 | `groupPolicy: allowlist` 但未配置 `guilds` | 在 `channels.discord` 中添加 `guilds` 对象，以服务器 ID 为 key（不要用 `allowFrom`，会报错） |
| Discord 配置 allowFrom 报错 | Discord 不支持 `allowFrom` 字段 | 改用 `guilds` 对象配置群聊白名单，见 Phase 2/4e 的 guilds 配置说明 |
| Discord 错误 4014 | Disallowed Intents | 在 Developer Portal 启用 Message Content Intent，重启 Gateway |
| Discord intents:content=disabled | Message Content Intent 未启用 | 访问 Bot 设置页面启用 Message Content Intent |
| Discord stopped 状态 | Token 或 Intents 问题 | 检查 Token 正确性，启用 Intents，查看日志 |
| Discord 配置键不识别 | 使用了错误的键名 | 使用 `channels.discord.token` 而不是 `botToken` |
| Discord Bot 无权限 | 授权链接权限为 0 | 使用包含权限值的授权链接（推荐 506944） |
| 模型返回 no output | 输出在其他环境 | 检查 Web/飞书/Telegram/钉钉/WhatsApp/Discord/其他 channels |
| 429 Too Many Requests | API 速率限制 | OpenClaw 默认携带完整上下文 + 失败重试，短时间内易触发限流。降低请求频率，或切换到消耗更低的模型（如千问、Kimi） |
| 模型列表可见但请求失败 | API Key 无效或余额不足 | 确认 API Key 有效且有余额，不要只看列表有没有模型，要确认能实际调用 |
| 新 session 仍用旧模型 | session 继承旧配置 | 用 `/new` 开新会话，或在 TUI 中用 `/model` 切换 |
| CLI 命令在 TUI 中无效 | 在聊天框输入了 shell 命令 | 配置/授权/审批命令必须在系统终端执行，TUI 只用于聊天和 `/` 开头的指令 |
| Node.js 版本混乱 | brew/nvm 混用 | 统一用 nvm 管理：`brew uninstall node && nvm install 22 && nvm alias default 22` |
| 新终端找不到 node/openclaw | shell 配置未加载 PATH | 检查 `~/.zshrc` 或 `~/.bashrc` 是否包含 nvm 初始化和正确的 PATH |
| 中转站模型不可用 | 中转站权限受限或模型不全 | 优先用官方 API，中转站排查成本高；永远不要明文泄露 API Key |
| 迁移后 API 密钥失效（HTTP 401） | 中转站可能有 IP/设备限制 | 更新 API 密钥或切换到官方 API；检查 fallback 模型是否可用 |
| 迁移后 OAuth 模型不可用 | OAuth token 未迁移或过期 | 重新登录：`openclaw models auth login --provider <provider-id>` |
| 迁移后工作空间路径错误 | Windows/Linux 路径格式不同 | 更新 `agents.defaults.workspace` 为目标系统格式 |
| 迁移后权限错误（Linux/macOS） | 文件权限过宽 | `chmod 700 ~/.openclaw && chmod 600 ~/.openclaw/openclaw.json` |
| 迁移后 IM 渠道无法连接 | 凭据未正确复制或网络问题 | 检查 Bot Token/App Secret，验证网络连接 |
| Connection error + LAN IP | 代理干扰 | SSH 隧道映射到 localhost，见 REFERENCE.md |
| Ollama 连接超时 | 防火墙/Ollama 未监听 | 确认 `OLLAMA_HOST=0.0.0.0` 且防火墙放行 |
| IM 渠道启动成功但无法回复消息 | 代理 Fake IP 劫持或 API 速率限制 | 检查日志：`journalctl --user -u openclaw-gateway.service --since "10 minutes ago" \| grep -E "(error\|failed)"` 查看具体错误 |
| Telegram/飞书 sendMessage failed: fetch failed | 代理 Fake IP 劫持导致网络请求失败 | 为 OpenClaw 禁用代理：创建 `~/.config/systemd/user/openclaw-gateway.service.d/no-proxy.conf` 添加 `Environment="HTTP_PROXY="` 等，然后 `systemctl --user daemon-reload && systemctl --user restart openclaw-gateway.service` |
| DNS 解析到 198.18.x.x (Fake IP) | Clash 等代理工具的 Fake IP 模式 | 在 Clash 配置中将 IM 渠道域名添加到 `fake-ip-filter` 或 `rules` 直连列表 |
| API rate limit reached (FailoverError) | 中转站 API 达到速率限制 | 切换到官方 API 或 OAuth 模型（如 openai-codex），或等待速率限制重置 |
| 渠道显示 running 但消息无回复 | 模型 API 失败或网络问题 | 检查日志中的 `lane task error` 和 `final reply failed`，确认模型 API 是否可用 |

**详细故障排查**：读取 `REFERENCE.md`

---

## 版本信息

- **Skill 版本**: 4.21
- **适用 OpenClaw 版本**: ≥ 2026.2.6-3
- **最后更新**: 2026-02-15
- **更新内容**:
  - **v4.21 (2026-02-15)**:
    - 🔧 **新增**：代理 Fake IP 劫持问题排查和解决方案
      - 症状：IM 渠道启动成功但无法回复消息，日志显示 `sendMessage failed: fetch failed`
      - 原因：Clash 等代理工具的 Fake IP 模式将 IM 渠道域名解析到虚拟 IP（如 198.18.x.x），导致连接超时
      - 解决方案 1：为 OpenClaw 禁用代理（创建 systemd override 配置）
      - 解决方案 2：在 Clash 配置中将 IM 渠道域名添加到直连规则或 fake-ip-filter
    - 🔧 **新增**：中转站 API 速率限制问题排查
      - 症状：`FailoverError: ⚠️ API rate limit reached`
      - 解决方案：切换到官方 API 或 OAuth 模型，或等待速率限制重置
    - 📊 **故障处理速查表新增 5 条**：
      - IM 渠道启动成功但无法回复消息
      - Telegram/飞书 sendMessage failed: fetch failed
      - DNS 解析到 198.18.x.x (Fake IP)
      - API rate limit reached (FailoverError)
      - 渠道显示 running 但消息无回复
    - 基于实际排查经验（2026-02-15 主实例消息无回复问题）
  - **v4.20 (2026-02-15)**:
    - 🔧 **新增**：docker-compose.yml 端口/路径硬编码最佳实践
      - `.env` 变量在某些 docker compose 版本下解析失败（端口被忽略，导致与宿主 gateway 端口冲突）
      - 推荐端口和 volumes 路径直接写死在 compose 文件中
      - 敏感值（image、token）仍可保留在 `.env`
    - 📊 **踩坑记录新增 1 条**：docker-compose.yml 中 .env 变量解析失败导致端口冲突
    - 基于实际运维经验（2026-02-15 八十二 Docker 升级时端口冲突问题）
  - **v4.19 (2026-02-14)**:
    - 🆕 **新增**：阿里云千问（通义千问）提供商支持
      - 端点：https://dashscope.aliyuncs.com/apps/anthropic
      - 模型 ID：qwen3-max-2026-01-23
      - 使用 Anthropic 兼容 API（anthropic-messages）
      - 支持 reasoning、text 和 image 输入
      - 添加到 provider-registry.json 和 Phase 0 配置收集选项
    - 🔧 **优化**：安装流程改进
      - 推荐直接使用 `npm install -g openclaw@latest`（更简单、更可靠）
      - 安装脚本降级为备选方案（仅当 npm 安装失败时使用）
      - Windows 特殊注意：管理员权限 + 执行策略设置
    - 🔧 **增强新手卡点速览**：
      - 新增「代理/TUN 模式导致安装失败」（需开启系统代理）
      - 新增「Windows PowerShell 执行策略限制」（需 Bypass 策略）
    - 📖 **来源**：基于社区教程（@0xValkyrie_ai）和实际部署经验整合
  - **v4.18 (2026-02-13)**:
    - 🆕 **新增**：Phase 7 配置迁移（跨系统/跨环境）
      - 完整的 Windows → Linux/macOS 迁移流程
      - 配置文件复制、路径更新、权限修复
      - 迁移后常见问题和解决方案（API 密钥失效、OAuth 凭据丢失、IM 渠道连接失败等）
      - 迁移验证清单和最佳实践
      - API 密钥可移植性分析（官方 API vs 中转站 API）
    - 🔧 **增强故障处理速查表**：新增 5 条迁移相关问题
      - 迁移后 API 密钥失效（HTTP 401）
      - 迁移后 OAuth 模型不可用
      - 迁移后工作空间路径错误
      - 迁移后权限错误（Linux/macOS）
      - 迁移后 IM 渠道无法连接
    - 📊 **实战经验**：基于 Windows → Linux 实际迁移案例（2026-02-13）
      - 发现中转站 API 密钥可能有 IP/设备限制
      - 验证 fallback 机制有效性（codesome/aigocode 失效后自动切换到 openai-codex）
      - 配置热重载机制验证（DingTalk allowFrom 配置自动重载）
    - 📖 **文档优化**：迁移场景覆盖
      - Windows ↔ Linux ↔ macOS 双向迁移
      - 备份恢复场景
      - 多机器部署场景
  - **v4.17 (2026-02-12)**:
    - 🆕 **新增**：Windows 双实例部署方案（Phase 6.4）
      - Docker 容器 + Windows 本地双实例架构
      - SSH 桥接方案：容器通过 SSH 免密连接执行 Windows 宿主机命令
      - 完整的 OpenSSH Server 安装配置流程（MSI 版本）
      - 6 个踩坑点详细记录（管理员 authorized_keys 路径、权限、公钥换行、服务注册等）
    - ⚠️ **记录 4 个已验证失败的跨环境方案**：nsenter、PowerShell HTTP Listener、Python Flask、共享文件轮询
    - 📊 **时间预算更新**：双实例部署额外 +15 分钟
    - 基于实际部署经验（2026-02-12 SSH 桥接方案实践）
  - **v4.16 (2026-02-12)**:
    - 📖 **新增**：新手常见卡点速览表（部署前必读）
      - 来源：社区高频问题总结（@Monica_xiaoM 等），覆盖 90% 新手踩坑场景
      - 5 大卡点：Node.js 环境混乱、CLI/TUI 混淆、模型看得到用不了、429 限流、中转站风险
    - 🔧 **增强 Phase 1**：Node.js 安装源冲突检测
      - 新增 brew/nvm 混用检测和修复流程
      - 新增新终端找不到命令的排查指引
    - 🔧 **增强 Phase 0**：成本与限流提醒（问题 5.5）
      - 新手建议先用消耗可控的模型
      - 中转站风险提醒
      - API Key 安全提醒
    - 🔧 **增强 Phase 3**：CLI vs TUI 使用提醒
      - 部署完成后输出清晰的命令执行位置指南
      - "命令在 shell，聊天在 TUI"
    - 🔧 **增强 Phase 6**：模型切换常见坑
      - "看得到但用不了"警告
      - 新 session 继承旧配置问题
      - 切模型用 CLI 指令不要在聊天框里切
    - 📊 **故障速查表新增 7 条**：429 限流、模型可见但不可用、session 继承、CLI/TUI 混淆、Node 版本混乱、终端 PATH 丢失、中转站不可用
  - **v4.15 (2026-02-12)**:
    - 🔥 **重要修正**：Discord 群聊白名单机制
      - Discord 不支持 `allowFrom` 字段（会报 `Unrecognized key` 配置错误）
      - 必须使用 `guilds` 对象配置群聊白名单，以服务器 ID 为 key
      - Phase 2：新增 Discord 配置 JSON 示例（含 `guilds` 白名单）
      - Phase 4e：新增 guilds 白名单配置步骤和获取服务器 ID 的方法
      - 故障速查：新增「Discord 群聊被 @ 不响应」和「Discord 配置 allowFrom 报错」
    - 🔧 **guilds 配置要点**：
      - `guilds.<服务器ID>.requireMention: true`：只在被 @ 时响应
      - `guilds.<服务器ID>.channels`：可选，限制特定频道
      - `guilds.<服务器ID>.users`：可选，限制特定用户
      - 不配置 `channels` 块 = 该服务器所有频道都允许
    - 基于实际排查经验（2026-02-12 Discord 群聊不响应问题）
  - **v4.14 (2026-02-12)**:
    - 🆕 **新增**：Discord 渠道集成支持
      - Phase 0：添加 Discord 到 IM 集成选项
      - Phase 4e：新增 Discord 集成完整流程（配置、Developer Portal 设置、验证、测试）
      - Phase 5：更新部署摘要，支持显示 Discord 状态
      - 故障处理速查：添加 Discord 相关故障排查（错误 4014、Intents、配置键名、权限等）
    - 🔥 **重要配置要点**：
      - Discord 使用 `openclaw config set` 命令配置（不同于其他 IM）
      - 配置键：`channels.discord.token`（不是 botToken）
      - 配置键：`channels.discord.dm.policy`（不是 dmPolicy）
      - 必须在 Developer Portal 启用 Message Content Intent
      - 推荐 Bot 权限值：506944（包含所有必要权限）
    - 📊 **部署时间预估**：Discord 集成约 15 分钟
    - 基于实际部署经验（2026-02-12 Discord 配置实践）的优化
  - **v4.13 (2026-02-11)**:
    - 🆕 **新增**：WhatsApp 渠道集成支持
      - Phase 0：添加 WhatsApp 到 IM 集成选项
      - Phase 2：添加 WhatsApp 配置 JSON 示例（个人账号和企业账号）
      - Phase 4d：新增 WhatsApp 集成完整流程（插件启用、配置、登录、测试）
      - Phase 5：更新部署摘要和复盘模板，支持显示 WhatsApp 状态
      - 故障处理速查：添加 WhatsApp 相关故障排查（插件启用、selfChatMode、配对策略、QR 码过期等）
    - 🔥 **重要配置要点**：
      - WhatsApp 插件默认为 disabled，必须手动启用
      - 个人账号必须设置 `selfChatMode: true`
      - 个人账号推荐使用 `pairing` 策略（不是 allowlist）
      - QR 码有效期约 20 秒，过期需重新生成
    - 📊 **部署时间预估**：WhatsApp 集成约 10 分钟
    - 基于实际部署经验（2026-02-11 WhatsApp 部署复盘）的优化
  - **v4.12 (2026-02-11)**:
    - 🔥 **重要修正**：配置收集流程重构
      - 移除对交互式脚本的依赖（`collect-config.sh` 和 `collect-config.ps1` 仅供用户手动执行参考）
      - 原因：Claude Code 的 Bash 工具不支持交互式输入（`read -p` / `Read-Host`）
      - 改用 AI 直接收集配置（使用 `AskUserQuestion`）
    - 🌍 **新增**：MiniMax 国内/国外端点区分
      - 国内端点：`https://api.minimaxi.com/anthropic`
      - 国外端点：`https://api.minimax.io/anthropic`
      - 在 Phase 0 配置收集时明确询问用户选择
    - 🔧 **优化**：自定义中转站配置流程
      - 明确区分 OpenAI 兼容和 Anthropic 兼容
      - 清晰的配置收集步骤
    - 📊 **优化**：部署复盘报告
      - 精确计算每个 Phase 的耗时（秒和分钟）
      - 报告位置从 `~/.openclaw/` 调整到用户根目录 `~/`
      - 使用 ISO 8601 时间戳格式
      - 增强配置摘要（包含端点信息）
    - 📖 **更新**：provider-registry.json
      - 添加 `minimax-cn` 和 `minimax-intl` 两个独立配置
      - 移除旧的 `minimax` 配置
  - **v4.11 (2026-02-10)**:
    - 🔥 **重要修正**：MiniMax 说明更新
      - 明确说明：只支持 MiniMax Coding Plan
      - 移除"免费版"/"付费版"的误导性说明
      - Coding Plan 使用 Anthropic 兼容端点
    - 📖 **新增**：手动部署 SOP 文档（MANUAL-SOP.md）
      - 详细的远程协助部署流程
      - Node.js 推荐浏览器下载（比 Homebrew 快）
      - sudo 权限问题的 3 种解决方案
      - 飞书配置详细步骤
      - 钉钉配置：一次性收集参数，逐条执行命令
      - 常见问题速查表
  - **v4.10 (2026-02-10)**:
    - 🔥 **重要修正**：MiniMax 配置更新
      - 只支持 MiniMax Coding Plan（付费版），不再支持按量使用 API
      - 原因：MiniMax API 和 Coding Plan 使用完全不同的 API Key，容易混淆导致错误
      - 正确配置：anthropic-messages + https://api.minimaxi.com/anthropic + 模型 ID: MiniMax-M2.1 这里要区分国内和国外，国内是https://api.minimaxi.com/anthropic 国外是https://api.minimax.io/anthropic
    - 新增 macOS 环境检查：Xcode 命令行工具、npm 权限检查
    - 新增 npm 用户目录配置方案（避免 sudo 权限问题）
    - 配置模板默认包含 `gateway.mode: "local"`（避免启动失败）
    - 飞书配置默认使用 `open` 策略 + `allowFrom: ["*"]`（避免 pairing 策略问题）
    - 飞书配置自动启用插件：`plugins.entries.feishu.enabled: true`
    - 故障处理速查表新增 10+ 个常见问题和解决方案
    - 基于两次实际部署经验（53 分钟 + 131 分钟）的优化
  - **v4.9 (2026-02-09)**:
    - 新增钉钉插件手动安装备选方案（解决 spawn EINVAL 错误）
    - 更新故障处理速查：添加具体的手动安装命令
    - 基于实际部署经验优化安装流程
  - **v4.8 (2026-02-09)**:
    - 新增钉钉（DingTalk）集成支持
    - Phase 0：添加钉钉选项到 IM 集成选择
    - Phase 2：添加钉钉配置 JSON 示例
    - Phase 4c：新增钉钉集成完整流程（开发者权限获取、机器人创建、插件安装、参数配置）
    - Phase 5：更新部署摘要和复盘模板，支持显示钉钉状态
    - 故障处理速查：添加钉钉相关故障排查（插件安装、配置、权限、消息接收方式等）
  - 支持飞书、Telegram、钉钉三种 IM 平台的任意组合配置
