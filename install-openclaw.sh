#!/bin/bash
# OpenClaw 自动安装脚本 (macOS/Linux)
# 用于远程部署场景 — 仅做系统操作，配置由 Claude 生成
# 版本: 4.0

set -e

# ============================================
# 颜色定义
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================
# TTY 输入处理（支持 curl | bash 模式）
# ============================================
if [ -t 0 ]; then
    TTY_INPUT="/dev/stdin"
else
    TTY_INPUT="/dev/tty"
fi

# ============================================
# 日志函数
# ============================================
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}$1${NC}"; }

# ============================================
# 确认提示函数
# ============================================
confirm() {
    local message="$1"
    local default="${2:-y}"
    if [ "$default" = "y" ]; then local prompt="[Y/n]"; else local prompt="[y/N]"; fi
    echo -en "${YELLOW}$message $prompt: ${NC}"
    read response < "$TTY_INPUT"
    response=${response:-$default}
    case "$response" in [yY][eE][sS]|[yY]) return 0 ;; *) return 1 ;; esac
}

# ============================================
# 重试机制函数
# ============================================
retry_command() {
    local max_retries="${1:-3}" timeout_sec="${2:-30}"
    shift 2
    local command="$@" retry_count=0 exit_code=0

    while [ $retry_count -lt $max_retries ]; do
        log_info "执行命令 (尝试 $((retry_count + 1))/$max_retries): $command"
        if command -v timeout &> /dev/null; then
            result=$(timeout $timeout_sec bash -c "$command" 2>&1) || exit_code=$?
            if [ "$exit_code" = "124" ]; then
                log_warn "命令超时（${timeout_sec}秒）"
                retry_count=$((retry_count + 1))
                continue
            fi
        else
            result=$(bash -c "$command" 2>&1) || exit_code=$?
        fi
        if [ $exit_code -eq 0 ]; then echo "$result"; return 0; fi
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            log_warn "命令失败，等待 2 秒后重试..."
            sleep 2
        fi
    done
    log_error "命令执行失败（已重试 $max_retries 次）"
    echo "$result"
    return 1
}

# ============================================
# 端口检测函数
# ============================================
check_port() {
    local port="$1"
    if command -v lsof &> /dev/null; then
        local pid=$(lsof -ti :$port 2>/dev/null | head -1)
        if [ -n "$pid" ]; then echo "$pid"; return 0; fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then echo "unknown"; return 0; fi
    fi
    return 1
}

# ============================================
# 主程序开始
# ============================================

echo "🚀 OpenClaw 自动安装脚本 v4.0"
echo "================================"
echo ""

# 检测操作系统
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
  WORKSPACE_PATH="$HOME/clawd"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  OS="linux"
  WORKSPACE_PATH="$HOME/clawd"
else
  log_error "不支持的操作系统: $OSTYPE"
  exit 1
fi

log_info "检测到操作系统: $OS"
echo ""

# ============================================
# 步骤 1/5: 环境检查
# ============================================
log_step "🔍 步骤 1/5: 环境检查"
echo "-------------------"

if ! command -v node &> /dev/null; then
  log_error "未找到 Node.js，请先安装 Node.js ≥22"
  exit 1
fi

NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 22 ]; then
  log_error "Node.js 版本过低 (当前: v$NODE_VERSION)，需要 ≥22"
  exit 1
fi

log_info "Node.js 版本: $(node --version)"

if ! command -v npm &> /dev/null; then
  log_error "未找到 npm"
  exit 1
fi

log_info "npm 版本: $(npm --version)"
echo ""

# ============================================
# 步骤 2/5: 检查现有服务
# ============================================
log_step "🔍 步骤 2/5: 检查现有服务"
echo "------------------------"

if pid=$(check_port 18789); then
    log_warn "检测到端口 18789 已被占用 (PID: $pid)"
    if confirm "是否停止现有服务？" "y"; then
        if [ "$pid" != "unknown" ]; then
            kill $pid 2>/dev/null || true
            sleep 2
            log_info "已停止现有服务"
        fi
    else
        log_warn "跳过安装，保留现有服务"
        exit 0
    fi
fi

log_info "端口 18789 可用"
echo ""

# ============================================
# 步骤 3/5: 安装 OpenClaw
# ============================================
log_step "📦 步骤 3/5: 安装 OpenClaw"
echo "------------------------"

if command -v openclaw &> /dev/null; then
  log_warn "OpenClaw 已安装，跳过安装步骤"
else
  log_info "正在通过官方脚本安装..."
  if ! curl -fsSL https://openclaw.ai/install.sh | bash; then
    log_error "安装失败，请检查网络连接"
    exit 1
  fi
  export PATH="$HOME/.openclaw/bin:$PATH"
fi

log_info "OpenClaw 版本: $(openclaw --version)"
echo ""

# ============================================
# 步骤 4/5: 目录创建与权限修复
# ============================================
log_step "📁 步骤 4/5: 目录创建与权限修复"
echo "-------------------------------"

mkdir -p "$HOME/.openclaw"
mkdir -p "$HOME/.openclaw/credentials"
mkdir -p "$WORKSPACE_PATH"

chmod 700 "$HOME/.openclaw/credentials"
log_info "目录已创建，凭据目录权限已设置为 700"
echo ""

# ============================================
# 步骤 5/5: 启动与验证
# ============================================
log_step "🚀 步骤 5/5: 启动与验证"
echo "----------------------"

# 启动 Gateway
if command -v setsid &> /dev/null; then
    setsid bash -c "openclaw gateway --port 18789" > /tmp/openclaw-gateway.log 2>&1 &
    log_info "使用 setsid 启动 Gateway"
else
    nohup openclaw gateway --port 18789 > /tmp/openclaw-gateway.log 2>&1 &
    disown 2>/dev/null || true
    log_info "使用 nohup 启动 Gateway"
fi

log_info "等待服务启动..."
sleep 5

if pid=$(check_port 18789); then
    log_info "Gateway 已启动 (PID: $pid)"
else
    log_error "Gateway 启动失败，请查看日志: /tmp/openclaw-gateway.log"
    exit 1
fi

# 验证
log_info "运行系统诊断..."
if retry_command 3 30 "openclaw doctor" > /dev/null 2>&1; then
    log_info "系统诊断通过"
else
    log_warn "系统诊断失败，但安装已完成"
fi

log_info "运行安全审计..."
if retry_command 3 30 "openclaw security audit" > /dev/null 2>&1; then
    log_info "安全审计通过"
else
    log_warn "安全审计失败，但安装已完成"
fi

echo ""
echo -e "${GREEN}🎉 OpenClaw 安装完成！${NC}"
echo ""
echo "📝 下一步（由 Claude 自动执行）："
echo "  1. 生成配置文件 (openclaw.json)"
echo "  2. 配置模型提供商和 API 密钥"
echo "  3. 重启 Gateway 并验证"
echo ""
