# OpenClaw 手动部署 SOP（远程协助专用）

**适用场景**：远程帮助用户部署，用户对命令行不熟悉，需要更快速、更可靠的部署方式。

**预计时间**：20-30 分钟（含飞书配置）

---

## 前置准备（5 分钟）

### 步骤 0：上传配置文件
让用户将以下文件上传到用户目录：
- `opencode.json`（如果有预配置）
- `openclaw-remote-deploy` 文件夹（本 skill）

**上传位置**：
- macOS/Linux: `~/.opencode/skills/openclaw-remote-deploy`
- Windows: `C:\Users\<用户名>\.opencode\skills\openclaw-remote-deploy`

### 步骤 1：打开代理（如果需要）
如果用户在中国大陆，需要先打开代理软件（如 Clash、V2Ray 等）。

### 步骤 2：安装 OpenCode
打开终端，执行：
```bash
curl -fsSL https://opencode.ai/install | bash
```

**可能问题 1：macOS 找不到 opencode 命令**

解决方法：
```bash
# 1. 编辑 zsh 配置文件（替换 <用户名> 为实际用户名）
echo 'export PATH=/Users/<用户名>/.opencode/bin:$PATH' >> ~/.zshrc

# 2. 重新加载配置
source ~/.zshrc

# 3. 验证
opencode --version
```

### 步骤 3：启动 OpenCode
```bash
opencode
```

在 OpenCode 中：
1. 输入 `/models` 选择 Sonnet 模型
2. 输入：`使用 openclaw-remote-deploy 进行安装`

---

## 安装过程中的常见问题

### 问题 1：macOS 未安装 Node.js

**推荐方案**：直接浏览器下载安装包（比命令行快）

1. 打开 Node.js 官网：https://nodejs.org/en/download/current
2. 下载 macOS 安装包（.pkg 文件）
3. 双击安装，一路下一步
4. 安装完成后，回到 OpenCode 继续

**为什么不用 Homebrew？**
- 很多用户没有安装 Homebrew
- Homebrew 安装 Node.js 需要 5-10 分钟
- 官方安装包只需要 1-2 分钟

### 问题 2：需要管理员权限（sudo 密码）

**场景**：安装 OpenClaw 或 zod 模块时提示需要密码

**解决方案 A**（推荐）：让用户输入密码
```bash
# 用户在自己的终端输入密码
sudo npm install -g openclaw
```

**解决方案 B**：如果用户愿意提供密码
1. 用户告诉你密码
2. 你在远程协助时帮忙输入
3. 安装完成后提醒用户修改密码

**解决方案 C**：配置 npm 使用用户目录（无需 sudo）
```bash
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
export PATH=~/.npm-global/bin:$PATH
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.zshrc
```

然后重新安装：
```bash
npm install -g openclaw
```

### 问题 3：安装过程中断

如果安装过程中断（如需要输入密码），处理方式：
1. 新开一个终端窗口
2. 执行需要 sudo 的命令
3. 回到 OpenCode，让 AI 继续安装

---

## 飞书配置（10 分钟）

### 步骤 1：创建飞书应用
1. 访问飞书开放平台：https://open.feishu.cn/app
2. 点击「创建企业自建应用」
3. 应用名称：让用户自己起（如"OpenClaw AI"）

### 步骤 2：启用机器人能力
1. 在应用详情页，点击「添加应用能力」
2. 选择「机器人」

### 步骤 3：配置权限
1. 点击「权限管理」
2. 点击「批量导入」
3. 粘贴以下权限配置：

```json
"scopes": {
  "tenant": [
    "im:app_feed_card:write",
    "im:biz_entity_tag_relation:read",
    "im:biz_entity_tag_relation:write",
    "im:chat",
    "im:chat.announcement:read",
    "im:chat.announcement:write_only",
    "im:chat.chat_pins:read",
    "im:chat.chat_pins:write_only",
    "im:chat.collab_plugins:read",
    "im:chat.collab_plugins:write_only",
    "im:chat.managers:write_only",
    "im:chat.members:read",
    "im:chat.members:write_only",
    "im:chat.menu_tree:read",
    "im:chat.menu_tree:write_only",
    "im:chat.moderation:read",
    "im:chat.tabs:read",
    "im:chat.tabs:write_only",
    "im:chat.top_notice:write_only",
    "im:chat.widgets:read",
    "im:chat.widgets:write_only",
    "im:chat:create",
    "im:chat:delete",
    "im:chat:moderation:write_only",
    "im:chat:operate_as_owner",
    "im:chat:read",
    "im:chat:readonly",
    "im:chat:update",
    "im:datasync.feed_card.time_sensitive:write",
    "im:message.group_msg",
    "im:message.pins:read",
    "im:message.pins:write_only",
    "im:message.reactions:read",
    "im:message.reactions:write_only",
    "im:message.urgent",
    "im:message.urgent.status:write",
    "im:message.urgent:phone",
    "im:message.urgent:sms",
    "im:message:recall",
    "im:message:send_multi_depts",
    "im:message:send_multi_users",
    "im:message:send_sys_msg",
    "im:message:update",
    "im:tag:read",
    "im:tag:write",
    "im:url_preview.update",
    "im:user_agent:read",
    "aily:file:read",
    "aily:file:write",
    "application:application.app_message_stats.overview:readonly",
    "application:application:self_manage",
    "application:bot.menu:write",
    "contact:contact.base:readonly",
    "contact:user.employee_id:readonly",
    "corehr:file:download",
    "event:ip_list",
    "im:chat.access_event.bot_p2p_chat:read",
    "im:chat.members:bot_access",
    "im:message",
    "im:message.group_at_msg:readonly",
    "im:message.p2p_msg:readonly",
    "im:message:readonly",
    "im:message:send_as_bot",
    "im:resource"
  ],
  "user": [
    "aily:file:read",
    "aily:file:write",
    "im:chat.access_event.bot_p2p_chat:read"
  ]
}
```

### 步骤 4：配置事件订阅（先要把后面的凭据发给ai，ai成功配置进去再设置）
1. 点击「事件订阅」
2. 订阅方式选择「长连接」
3. 添加事件：`im.message.receive_v1`

### 步骤 5：发布应用
1. 点击「版本管理与发布」
2. 创建版本（版本号和描述自定义）
3. **重要**：点击右侧的「发布」按钮

### 步骤 6：获取凭据
在应用详情页获取：
- **App ID**（应用 ID）
- **App Secret**（应用密钥）

将这两个凭据提供给 AI，AI 会自动配置。

---

## 钉钉配置（20 分钟）

### 步骤 1：获取开发者权限

**方式 1：自己注册组织**
1. 访问钉钉官网教程：https://alidocs.dingtalk.com/i/p/Y7kmbokZp3pgGLq2/docs/3KLw95QMzkb8gDMZ3qaDWAjrymPeEN2q
2. 按照教程注册组织，获得管理员权限

**方式 2：联系现有组织管理员**
1. 联系你所在组织的管理员
2. 让管理员给你开通开发者权限

### 步骤 2：创建机器人应用（注意这一步很可能有个地方搞错，千问不要设置成小程序，不然得重新配置）
1. 打开钉钉开发者网页版：https://open-dev.dingtalk.com/
2. 扫码登录，选择你有管理员权限的组织
3. 确认主页显示你有开发者权限
4. 添加机器人：
   - 机器人简介和描述可以自定义
   - **重要**：消息接收方式必须选择「Stream」，保持默认，不要修改

### 步骤 3：配置权限（其实就是全选）
1. 在权限管理中搜索「卡片」
2. 将所有卡片相关权限全部打开

### 步骤 4：发布版本
1. 点击「版本管理与发布」
2. 创建新版本（版本号和版本描述自定义）
3. 保存后，**一定要在右边再点击「发布」按钮**

### 步骤 5：获取配置参数（一次性收集）
在应用详情页面获取以下参数：
- **Corp ID**（企业 ID）
- **Client ID**（应用 ID）
- **Client Secret**（应用密钥）
- **Agent ID**（机器人 ID）

**重要**：将这 4 个参数一次性提供给 AI，AI 会逐条执行配置命令。

### 步骤 6：AI 执行配置（一步一步填）
AI 会逐条执行以下命令（每条命令执行后检查回显）：

```bash
openclaw config set channels.dingtalk.enabled true
openclaw config set channels.dingtalk.clientId <Client ID>
openclaw config set channels.dingtalk.clientSecret <Client Secret>
openclaw config set channels.dingtalk.robotCode <Client ID>
openclaw config set channels.dingtalk.corpId <Corp ID>
openclaw config set channels.dingtalk.agentId <Agent ID>
openclaw config set channels.dingtalk.dmPolicy open
openclaw config set channels.dingtalk.groupPolicy open
openclaw config set channels.dingtalk.messageType markdown
openclaw config set channels.dingtalk.debug false
```

**重要**：每条命令执行后，检查回显最后一条信息是否为「Restart the gateway to apply.」，如果不是，说明参数设置不对，配置未成功。

### 步骤 7：重启 Gateway
```bash
openclaw gateway restart
sleep 5
openclaw channels list  # 应显示 "DingTalk: configured, enabled"
```

### 步骤 8：测试钉钉机器人
1. 打开钉钉客户端
2. 点击搜索，输入你的机器人名字（往下翻）
3. 发送任意消息测试
4. 机器人应该能够正常响应

---

## 验证部署

部署完成后，验证：
```bash
openclaw --version          # 确认版本 ≥ 2026.2.6-3
openclaw gateway status     # 应显示 running
openclaw channels list      # 应显示对应 channel 状态
```

在飞书/钉钉中找到机器人，发送消息测试。

---

## 常见问题速查

| 问题 | 解决方案 |
|------|----------|
| macOS 找不到 opencode | 添加到 PATH：`echo 'export PATH=/Users/<用户名>/.opencode/bin:$PATH' >> ~/.zshrc && source ~/.zshrc` |
| Node.js 未安装 | 浏览器下载安装包：https://nodejs.org/en/download/current |
| 需要 sudo 密码 | 让用户输入密码，或配置 npm 使用用户目录 |
| 安装过程中断 | 新开终端执行 sudo 命令，回到 OpenCode 继续 |
| 飞书机器人无回复 | 检查权限配置、事件订阅、应用是否发布 |
| 钉钉配置不生效 | 检查每条命令回显是否为「Restart the gateway to apply.」 |
| 钉钉机器人不响应 | 检查 Corp ID、Client ID、Client Secret、Agent ID 是否正确 |

---

## 时间预算

- 前置准备：5 分钟
- OpenClaw 安装：5-10 分钟（取决于是否需要安装 Node.js）
- 模型配置：2 分钟
- 飞书配置：10 分钟
- 钉钉配置：20 分钟
- 验证测试：3 分钟

**总计**：25-40 分钟
