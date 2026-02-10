---
name: openclaw-remote-deploy
description: OpenClaw 远程一键部署（状态机 v4.11）— 30 分钟内完成含飞书/Telegram/钉钉集成的完整部署
argument-hint: "[optional: windows/macos/linux]"
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, Task, AskUserQuestion
---

# OpenClaw Remote Deploy v4.11 — 状态机执行流程

> 核心原则：**一次性收集所有信息 → 连续自动执行**
> 时间预算：无 IM 13 min / 含飞书 30 min / 含 Telegram 18 min / 含钉钉 20 min

## 技能包文件

| 文件 | 用途 |
|------|------|
| `SKILL.md` | 执行流程（本文件） |
| `collect-config.sh` | 配置收集脚本 (macOS/Linux) ⚡ |
| `collect-config.ps1` | 配置收集脚本 (Windows) ⚡ |
| `provider-registry.json` | 预置模型提供商配置（已验证 provider + 自定义模板） |
| `feishu-permissions.json` | 飞书权限 JSON（可直接批量导入） |
| `install-openclaw.sh` | macOS/Linux 安装脚本 |
| `install-openclaw.ps1` | Windows 安装脚本 |
| `REFERENCE.md` | 合并参考文档（故障排查 + 飞书 + 安装指南） |

---

## Phase 0: 信息收集 (< 1 min) — 脚本自动化

**优先使用配置收集脚本**（快速、确定性）：

**⚠️ 备用机制**：如果脚本执行失败或不可用，自动回退到方法 B（AI 提问方式）。

### 方法 A: 使用脚本收集（推荐）⚡

根据 OS 运行对应脚本：
```bash
# macOS/Linux
bash collect-config.sh

# Windows
powershell -ExecutionPolicy Bypass -File collect-config.ps1
```

脚本会自动：
1. 检测操作系统
2. 显示模型提供商选项
3. 收集 API Keys
4. 询问是否需要 fallback
5. 询问是否需要飞书
6. 生成配置文件：`~/.openclaw/deployment-config.json`

**然后读取配置文件**：
```bash
Read ~/.openclaw/deployment-config.json
```

### 方法 B: 手动收集（备选）

如果脚本不可用，使用 AskUserQuestion 逐个收集：

#### 问题 1: 操作系统
- Windows / macOS / Linux（如果参数已提供则跳过）

#### 问题 2: 模型提供商
读取 `provider-registry.json`，列出选项：
- Kimi (Moonshot) — anthropic-messages
- Minimax Coding Plan — anthropic-messages ⚠️ 只支持 Coding Plan
- OpenRouter — openai-completions
- Volcengine (火山引擎) — openai-completions
- Ollama (本地/局域网) — openai-completions ⚠️ 需额外网络检查
- 自定义 OpenAI 兼容 — 需提供 baseUrl
- 自定义 Anthropic 兼容 — 需提供 baseUrl

**如果用户选择 Ollama**，额外收集：
- Ollama 服务器地址（默认 127.0.0.1:11434）
- 模型名称（如 qwen:7b, llama3:8b 等）

#### 问题 3: API Key
- 对应提供商的 API Key

#### 问题 4: 模型选择
- 根据选择的提供商，提供默认模型建议，允许用户自定义
- 询问是否需要 fallback 模型（推荐）

#### 问题 5: IM 集成
- 是否需要 IM 集成？(是/否)
- 如果是，选择类型：
  - **飞书**：App ID + App Secret（可以稍后在 Phase 4 提供）
  - **Telegram**：Bot Token（可以稍后在 Phase 4 提供）
  - **钉钉**：Corp ID + Client ID + Client Secret + Agent ID（可以稍后在 Phase 4 提供）
  - **多个集成**：可以同时配置飞书、Telegram 和钉钉

**收集完毕后，打印确认摘要，等待用户确认。**

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
- 根据 OS 选择安装脚本：
  - macOS/Linux: 读取 `install-openclaw.sh` → Bash 执行
  - Windows: 读取 `install-openclaw.ps1` → PowerShell 执行
- 脚本功能：环境检查 → 安装 → 目录创建 → 权限修复 → 启动

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
  Token:    <auth-token>
═══════════════════════════════════════
```

### 自动复盘与数据收集

**重要**：每次部署完成后，自动生成部署复盘报告，用于持续优化。

用 Write 工具创建复盘文件：`~/.openclaw/deployment-review-<timestamp>.md`

**复盘内容**（脱敏处理）：
```markdown
# OpenClaw 部署复盘 - <日期时间>

## 部署配置
- OS: <操作系统>
- OpenClaw 版本: <版本号>
- 主模型提供商: <provider>（脱敏：不记录 API Key）
- 备用模型: <是/否>
- 飞书集成: <是/否>
- Telegram 集成: <是/否>
- 钉钉集成: <是/否>

## 部署过程
- Phase 0 耗时: <分钟>
- Phase 1 耗时: <分钟>
  - 是否需要升级: <是/否>
  - 是否需要安装 zod: <是/否>
- Phase 2 耗时: <分钟>
- Phase 3 耗时: <分钟>
- Phase 4 耗时: <分钟>（如果有 IM 集成）
  - 飞书: <分钟>
  - Telegram: <分钟>
  - 钉钉: <分钟>
- Phase 5 耗时: <分钟>
- **总耗时**: <分钟>

## 遇到的问题
- 列出所有遇到的错误和解决方法
- 记录任何非标准流程

## 优化建议
- 基于本次部署经验的改进建议
- 可以简化的步骤
- 需要补充的文档

## 验证结果
- Gateway 状态: <运行中/失败>
- 模型测试: <成功/失败>
- 飞书连接: <成功/失败/未配置>
- Telegram 连接: <成功/失败/未配置>
- 钉钉连接: <成功/失败/未配置>
```

**文件位置**：
- Windows: `C:\Users\<username>\.openclaw\deployment-review-<timestamp>.md`
- macOS/Linux: `~/.openclaw/deployment-review-<timestamp>.md`

**隐私保护**：
- ✅ 记录：OS、版本、提供商名称、耗时、问题
- ❌ 不记录：API Key、Token、App ID、App Secret、IP 地址

---

## Phase 6: 部署后操作（可选）

### 6.1 切换默认模型

**适用场景**：
- 已经部署完成，想切换到另一个已配置的模型
- 想调整 fallback 模型的优先级
- 想在多个提供商之间切换

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
| 模型返回 no output | 输出在其他环境 | 检查 Web/飞书/Telegram/钉钉/其他 channels |
| Connection error + LAN IP | 代理干扰 | SSH 隧道映射到 localhost，见 REFERENCE.md |
| Ollama 连接超时 | 防火墙/Ollama 未监听 | 确认 `OLLAMA_HOST=0.0.0.0` 且防火墙放行 |

**详细故障排查**：读取 `REFERENCE.md`

---

## 版本信息

- **Skill 版本**: 4.11
- **适用 OpenClaw 版本**: ≥ 2026.2.6-3
- **最后更新**: 2026-02-10
- **更新内容**:
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
