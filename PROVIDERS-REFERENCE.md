# OpenClaw Model Providers Reference

> 本文档是 OpenClaw 官方文档的摘要，用于指导配置生成。
> 官方文档：https://docs.openclaw.ai/

## 配置结构概览

OpenClaw 的配置文件 `openclaw.json` 采用以下结构：

```json
{
  "env": {
    "<PROVIDER_API_KEY_VAR>": "<API Key>"
  },
  "gateway": {
    "bind": "loopback",
    "port": 18789,
    "mode": "local",
    "auth": {
      "token": "<64位hex>"
    },
    "controlUi": {
      "allowInsecureAuth": false
    }
  },
  "agents": {
    "defaults": {
      "workspace": "<工作目录>",
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
        "baseUrl": "<API端点>",
        "api": "<openai-completions 或 anthropic-messages>",
        "apiKey": "${<ENV_VAR>}",
        "models": [
          {
            "id": "<model-id>",
            "name": "<显示名称>",
            "reasoning": false,
            "input": ["text"],
            "contextWindow": 200000,
            "maxTokens": 8192
          }
        ]
      }
    }
  },
  "channels": {
    // IM 集成配置（飞书/Telegram/钉钉）
  },
  "plugins": {
    "entries": {
      // 插件配置
    }
  }
}
```

## 关键配置说明

### 1. Gateway 配置

**必需字段**：
- `mode: "local"` - 本地模式（必须设置，否则启动失败）
- `bind: "loopback"` - 绑定到本地回环地址
- `port: 18789` - 默认端口
- `auth.token` - 64位十六进制认证令牌（自动生成）

### 2. Models 配置

**mode 字段**：
- `"replace"` - 覆盖写入，避免历史残留 provider 被合并
- `"merge"` - 合并模式（不推荐，会导致列表变长）

**API 类型**：
- `"openai-completions"` - OpenAI 兼容 API
- `"anthropic-messages"` - Anthropic 兼容 API

### 3. Agents 配置

**defaults.models 字段**：
- 作为 allowlist，控制 `/model` 和 `/models` 的可见范围
- 只展示列出的模型 + 当前默认/回退模型
- 如果为空，则显示所有配置的模型

**workspace 路径**：
- Windows: `C:\\Users\\<username>\\clawd`
- macOS/Linux: `~/clawd`

## 模型提供商配置示例

### Kimi (Moonshot)

```json
{
  "env": {
    "KIMI_API_KEY": "sk-..."
  },
  "models": {
    "mode": "replace",
    "providers": {
      "kimi": {
        "baseUrl": "https://api.kimi.com/coding",
        "api": "anthropic-messages",
        "apiKey": "${KIMI_API_KEY}",
        "models": [
          {
            "id": "kimi-latest",
            "name": "Kimi Latest",
            "reasoning": false,
            "input": ["text"],
            "contextWindow": 128000,
            "maxTokens": 8192
          }
        ]
      }
    }
  }
}
```

### MiniMax Coding Plan（国内端点）

```json
{
  "env": {
    "MINIMAX_API_KEY": "sk-..."
  },
  "models": {
    "mode": "replace",
    "providers": {
      "minimax": {
        "baseUrl": "https://api.minimaxi.com/anthropic",
        "api": "anthropic-messages",
        "apiKey": "${MINIMAX_API_KEY}",
        "models": [
          {
            "id": "MiniMax-M2.1",
            "name": "MiniMax M2.1 (Coding Plan - 国内)",
            "reasoning": false,
            "input": ["text"],
            "contextWindow": 200000,
            "maxTokens": 8192
          }
        ]
      }
    }
  }
}
```

### MiniMax Coding Plan（国外端点）

```json
{
  "env": {
    "MINIMAX_API_KEY": "sk-..."
  },
  "models": {
    "mode": "replace",
    "providers": {
      "minimax": {
        "baseUrl": "https://api.minimax.io/anthropic",
        "api": "anthropic-messages",
        "apiKey": "${MINIMAX_API_KEY}",
        "models": [
          {
            "id": "MiniMax-M2.1",
            "name": "MiniMax M2.1 (Coding Plan - 国外)",
            "reasoning": false,
            "input": ["text"],
            "contextWindow": 200000,
            "maxTokens": 8192
          }
        ]
      }
    }
  }
}
```

### OpenRouter

```json
{
  "env": {
    "OPENROUTER_API_KEY": "sk-..."
  },
  "models": {
    "mode": "replace",
    "providers": {
      "openrouter": {
        "baseUrl": "https://openrouter.ai/api/v1",
        "api": "openai-completions",
        "apiKey": "${OPENROUTER_API_KEY}",
        "models": [
          {
            "id": "anthropic/claude-sonnet-4-5",
            "name": "Claude Sonnet 4.5 (via OpenRouter)",
            "reasoning": false,
            "input": ["text", "image"],
            "contextWindow": 200000,
            "maxTokens": 8192
          }
        ]
      }
    }
  }
}
```

### 自定义 Anthropic 兼容中转站

```json
{
  "env": {
    "CUSTOM_API_KEY": "sk-..."
  },
  "models": {
    "mode": "replace",
    "providers": {
      "custom-proxy": {
        "baseUrl": "https://your-proxy.com/v1",
        "api": "anthropic-messages",
        "apiKey": "${CUSTOM_API_KEY}",
        "models": [
          {
            "id": "claude-opus-4-6",
            "name": "Claude Opus 4.6 (via Proxy)",
            "reasoning": false,
            "input": ["text", "image"],
            "contextWindow": 200000,
            "maxTokens": 8192
          }
        ]
      }
    }
  }
}
```

### 自定义 OpenAI 兼容中转站

```json
{
  "env": {
    "CUSTOM_API_KEY": "sk-..."
  },
  "models": {
    "mode": "replace",
    "providers": {
      "custom-proxy": {
        "baseUrl": "https://your-proxy.com/v1",
        "api": "openai-completions",
        "apiKey": "${CUSTOM_API_KEY}",
        "models": [
          {
            "id": "gpt-4",
            "name": "GPT-4 (via Proxy)",
            "reasoning": false,
            "input": ["text"],
            "contextWindow": 128000,
            "maxTokens": 8192
          }
        ]
      }
    }
  }
}
```

## Model Failover（备用模型）

OpenClaw 支持配置备用模型，当主模型失败时自动切换。

**配置示例**：

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "minimax/MiniMax-M2.1",
        "fallbacks": ["kimi/kimi-latest", "openrouter/anthropic/claude-sonnet-4-5"]
      },
      "models": {
        "minimax/MiniMax-M2.1": {},
        "kimi/kimi-latest": {},
        "openrouter/anthropic/claude-sonnet-4-5": {}
      }
    }
  }
}
```

**最佳实践**：
- 建议至少配置 1 个 fallback 模型（提高可用性）
- Fallback 模型应该使用不同的提供商（避免单点故障）
- 按优先级排序：最优先的 fallback 放在数组第一位

## IM 集成配置

### 飞书（Feishu）

```json
{
  "channels": {
    "feishu": {
      "enabled": true,
      "dmPolicy": "open",
      "allowFrom": ["*"],
      "accounts": {
        "main": {
          "appId": "<App ID>",
          "appSecret": "<App Secret>",
          "botName": "OpenClaw AI"
        }
      }
    }
  },
  "plugins": {
    "entries": {
      "feishu": {
        "enabled": true
      }
    }
  }
}
```

### Telegram

```json
{
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "<Bot Token>",
      "dmPolicy": "pairing"
    }
  }
}
```

### 钉钉（DingTalk）

```json
{
  "channels": {
    "dingtalk": {
      "enabled": true,
      "clientId": "<Client ID>",
      "clientSecret": "<Client Secret>",
      "robotCode": "<Client ID>",
      "corpId": "<Corp ID>",
      "agentId": "<Agent ID>",
      "dmPolicy": "open",
      "groupPolicy": "open",
      "messageType": "markdown",
      "debug": false
    }
  }
}
```

## 配对策略（DM Policy）

| 策略 | 说明 | 适用场景 |
|------|------|---------|
| `pairing` | 需要配对码验证（默认，推荐） | 个人使用，需要安全控制 |
| `allowlist` | 仅允许 `allowFrom` 列表中的用户 | 已知用户列表，无需每次配对 |
| `open` | 允许所有用户（需设置 `allowFrom: ["*"]`） | 公开服务，不推荐 |
| `disabled` | 禁用私聊 | 仅在群组中使用 |

## 常见问题

### 1. Gateway 启动失败："set gateway.mode=local"

**原因**：配置缺少 `gateway.mode` 字段

**解决**：在 `openclaw.json` 的 `gateway` 配置中添加 `"mode": "local"`

### 2. MiniMax API 返回 insufficient balance

**原因**：余额不足或配置错误

**解决**：
- 检查余额
- 确认使用正确的端点（Coding Plan 用 `/anthropic`，不是 `/v1`）
- 确认 API 类型为 `anthropic-messages`

### 3. Provider in cooldown (rate_limit)

**原因**：API 返回错误后进入冷却

**解决**：重启 Gateway：`openclaw gateway restart`

### 4. 模型列表显示过多内置模型

**原因**：`models.mode` 未设置为 `"replace"`

**解决**：在配置中设置 `"models": { "mode": "replace" }`

### 5. OAuth 模型不可见/无法使用

**原因**：OAuth token 过期或丢失

**解决**：运行 `openclaw models auth login --provider <provider-id>` 重新登录

## 参考链接

- **Model Providers**: https://docs.openclaw.ai/concepts/model-providers
- **Model Failover**: https://docs.openclaw.ai/concepts/model-failover
- **Providers 子页面**: https://docs.openclaw.ai/providers/*
- **Configuration**: https://docs.openclaw.ai/configuration
- **Channels**: https://docs.openclaw.ai/channels

---

**最后更新**: 2026-02-11
**版本**: v4.12
