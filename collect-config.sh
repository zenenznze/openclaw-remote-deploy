#!/bin/bash
# OpenClaw 配置收集脚本 (macOS/Linux)
# 用于快速收集部署所需的所有信息
# 版本: 4.3

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 输出函数
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

# 配置文件路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE="$HOME/.openclaw/deployment-config.json"
PROVIDER_REGISTRY="$SCRIPT_DIR/provider-registry.json"

# 创建输出目录
mkdir -p "$HOME/.openclaw"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  OpenClaw 配置收集向导 v4.3"
echo "═══════════════════════════════════════════════════════════"
echo ""

# 1. 检测操作系统
info "检测操作系统..."
OS_TYPE=$(uname -s)
case "$OS_TYPE" in
    Darwin*) OS="macos" ;;
    Linux*)  OS="linux" ;;
    *)       OS="unknown" ;;
esac
success "操作系统: $OS"

# 2. 选择模型提供商
echo ""
info "选择模型提供商:"
echo "  1) Kimi (Moonshot) - 推荐"
echo "  2) Minimax"
echo "  3) Ollama (本地/局域网)"
echo "  4) 自定义 OpenAI 兼容"
echo "  5) 自定义 Anthropic 兼容"
read -p "请选择 [1-5]: " provider_choice

case $provider_choice in
    1) PROVIDER="kimi" ;;
    2) PROVIDER="minimax" ;;
    3) PROVIDER="ollama" ;;
    4) PROVIDER="custom-openai" ;;
    5) PROVIDER="custom-anthropic" ;;
    *) error "无效选择"; exit 1 ;;
esac

# 3. 收集主模型配置
echo ""
info "配置主模型..."

if [ "$PROVIDER" = "ollama" ]; then
    read -p "请输入 Ollama 服务器地址 [127.0.0.1:11434]: " OLLAMA_SERVER
    OLLAMA_SERVER=${OLLAMA_SERVER:-127.0.0.1:11434}
    read -p "请输入模型名称 [qwen:7b]: " MODEL_ID
    MODEL_ID=${MODEL_ID:-qwen:7b}
    BASE_URL="http://$OLLAMA_SERVER/v1"
    API_KEY="ollama"

    # 代理检测
    PROXY_DETECTED=$(env | grep -i proxy | head -n 1)
    if [ -n "$PROXY_DETECTED" ] && [[ ! "$OLLAMA_SERVER" =~ ^127\.0\.0\.1 ]] && [[ ! "$OLLAMA_SERVER" =~ ^localhost ]]; then
        echo ""
        warn "检测到系统代理: $PROXY_DETECTED"
        warn "OpenClaw 的 HTTP 客户端不支持 NO_PROXY，LAN IP 连接会失败！"
        warn "建议：使用 SSH 隧道将远程端口映射到 localhost"
        echo "   ssh -f -N -L 11434:localhost:11434 user@<server-ip>"
        echo "   然后服务器地址填 127.0.0.1:11434"
        echo ""
        read -p "是否已设置 SSH 隧道？[y/N]: " ssh_tunnel_ready
        if [[ ! "$ssh_tunnel_ready" =~ ^[Yy]$ ]]; then
            warn "请先设置 SSH 隧道后再继续"
        fi
    fi
elif [ "$PROVIDER" = "custom-openai" ] || [ "$PROVIDER" = "custom-anthropic" ]; then
    read -p "请输入 baseUrl: " BASE_URL
    read -p "请输入模型 ID: " MODEL_ID
    read -p "请输入 API Key: " API_KEY
else
    BASE_URL=""
    MODEL_ID=""
    read -p "请输入 API Key: " API_KEY
fi

# 4. 询问是否需要 fallback
echo ""
read -p "是否配置备用模型? [y/N]: " need_fallback
if [[ "$need_fallback" =~ ^[Yy]$ ]]; then
    if [ "$PROVIDER" = "kimi" ]; then
        echo "  1) Minimax - 推荐"
        echo "  2) 不需要"
        read -p "选择备用模型 [1-2]: " fallback_choice

        case $fallback_choice in
            1) FALLBACK_PROVIDER="minimax" ;;
            *) FALLBACK_PROVIDER="" ;;
        esac
    elif [ "$PROVIDER" = "minimax" ]; then
        echo "  1) Kimi (Moonshot) - 推荐"
        echo "  2) 不需要"
        read -p "选择备用模型 [1-2]: " fallback_choice

        case $fallback_choice in
            1) FALLBACK_PROVIDER="kimi" ;;
            *) FALLBACK_PROVIDER="" ;;
        esac
    else
        echo "  1) Kimi (Moonshot) - 推荐"
        echo "  2) Minimax"
        echo "  3) 不需要"
        read -p "选择备用模型 [1-3]: " fallback_choice

        case $fallback_choice in
            1) FALLBACK_PROVIDER="kimi" ;;
            2) FALLBACK_PROVIDER="minimax" ;;
            *) FALLBACK_PROVIDER="" ;;
        esac
    fi

    if [ -n "$FALLBACK_PROVIDER" ]; then
        read -p "请输入备用模型的 API Key: " FALLBACK_API_KEY
    fi
else
    FALLBACK_PROVIDER=""
    FALLBACK_API_KEY=""
fi

# 5. 询问是否需要飞书
echo ""
read -p "是否需要飞书集成? [y/N]: " need_feishu
if [[ "$need_feishu" =~ ^[Yy]$ ]]; then
    FEISHU_ENABLED="true"
    read -p "飞书 App ID (可稍后提供，直接回车跳过): " FEISHU_APP_ID
    read -p "飞书 App Secret (可稍后提供，直接回车跳过): " FEISHU_APP_SECRET
else
    FEISHU_ENABLED="false"
    FEISHU_APP_ID=""
    FEISHU_APP_SECRET=""
fi

# 6. 生成配置 JSON
echo ""
info "生成配置文件..."

cat > "$OUTPUT_FILE" <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "os": "$OS",
  "provider": {
    "name": "$PROVIDER",
    "baseUrl": "$BASE_URL",
    "modelId": "$MODEL_ID",
    "apiKey": "$API_KEY"$([ "$PROVIDER" = "ollama" ] && echo ",
    \"ollamaServer\": \"$OLLAMA_SERVER\"")
  },
  "fallback": {
    "enabled": $([ -n "$FALLBACK_PROVIDER" ] && echo "true" || echo "false"),
    "provider": "$FALLBACK_PROVIDER",
    "apiKey": "$FALLBACK_API_KEY"
  },
  "feishu": {
    "enabled": $FEISHU_ENABLED,
    "appId": "$FEISHU_APP_ID",
    "appSecret": "$FEISHU_APP_SECRET"
  }
}
EOF

success "配置已保存到: $OUTPUT_FILE"

# 7. 显示摘要
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  配置摘要"
echo "═══════════════════════════════════════════════════════════"
echo "操作系统:     $OS"
echo "主模型:       $PROVIDER"
echo "备用模型:     ${FALLBACK_PROVIDER:-无}"
echo "飞书集成:     $([ "$FEISHU_ENABLED" = "true" ] && echo "是" || echo "否")"
echo "═══════════════════════════════════════════════════════════"
echo ""
success "配置收集完成！现在可以运行 /openclaw-remote-deploy 开始部署"
echo ""
