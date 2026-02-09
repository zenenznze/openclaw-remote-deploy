# OpenClaw 自动安装脚本 (Windows PowerShell)
# 用于远程部署场景 — 仅做系统操作，配置由 Claude 生成
# 版本: 4.0

$ErrorActionPreference = "Stop"

# ============================================
# 日志函数
# ============================================
function Log-Info { param([string]$Message); Write-Host "[INFO] $Message" -ForegroundColor Green }
function Log-Warn { param([string]$Message); Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Log-Error { param([string]$Message); Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Log-Step { param([string]$Message); Write-Host $Message -ForegroundColor Cyan }

# ============================================
# 重试机制函数
# ============================================
function Invoke-RetryCommand {
    param([ScriptBlock]$Command, [int]$MaxRetries = 3, [int]$TimeoutSeconds = 30)
    $retryCount = 0
    while ($retryCount -lt $MaxRetries) {
        try {
            Log-Info "执行命令 (尝试 $($retryCount + 1)/$MaxRetries)"
            $job = Start-Job -ScriptBlock $Command
            $completed = Wait-Job $job -Timeout $TimeoutSeconds
            if ($completed) {
                $result = Receive-Job $job; Remove-Job $job; return $result
            } else {
                Log-Warn "命令超时（${TimeoutSeconds}秒）"
                Stop-Job $job; Remove-Job $job
            }
        } catch { Log-Warn "命令失败: $_" }
        $retryCount++
        if ($retryCount -lt $MaxRetries) { Log-Warn "等待 2 秒后重试..."; Start-Sleep -Seconds 2 }
    }
    Log-Error "命令执行失败（已重试 $MaxRetries 次）"
    throw "命令执行失败"
}

# ============================================
# 端口检测函数
# ============================================
function Test-Port {
    param([int]$Port)
    try {
        $connection = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
        if ($connection) { return $connection.OwningProcess }
    } catch {
        $netstat = netstat -ano | Select-String ":$Port "
        if ($netstat) { return "unknown" }
    }
    return $null
}

# ============================================
# 主程序开始
# ============================================

Write-Host "🚀 OpenClaw 自动安装脚本 v4.0" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# 步骤 1/5: 环境检查
Log-Step "🔍 步骤 1/5: 环境检查"
Write-Host "-------------------"

try {
    $nodeVersion = node --version
    $nodeMajor = [int]($nodeVersion -replace 'v(\d+)\..*', '$1')
    if ($nodeMajor -lt 22) {
        Log-Error "Node.js 版本过低 (当前: $nodeVersion)，需要 ≥22"
        exit 1
    }
    Log-Info "Node.js 版本: $nodeVersion"
} catch {
    Log-Error "未找到 Node.js，请先安装 Node.js ≥22"
    exit 1
}

try {
    $npmVersion = npm --version
    Log-Info "npm 版本: $npmVersion"
} catch {
    Log-Error "未找到 npm"
    exit 1
}

Write-Host ""

# 步骤 2/5: 检查现有服务
Log-Step "🔍 步骤 2/5: 检查现有服务"
Write-Host "------------------------"

$existingPid = Test-Port -Port 18789
if ($existingPid) {
    Log-Warn "检测到端口 18789 已被占用 (PID: $existingPid)"
    $response = Read-Host "是否停止现有服务？[Y/n]"
    if ($response -eq "" -or $response -match "^[Yy]") {
        if ($existingPid -ne "unknown") {
            try {
                Stop-Process -Id $existingPid -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
                Log-Info "已停止现有服务"
            } catch { Log-Warn "无法停止现有服务: $_" }
        }
    } else {
        Log-Warn "跳过安装，保留现有服务"
        exit 0
    }
}

Log-Info "端口 18789 可用"
Write-Host ""

# 步骤 3/5: 安装 OpenClaw
Log-Step "📦 步骤 3/5: 安装 OpenClaw"
Write-Host "------------------------"

try {
    $openclawVersion = openclaw --version
    Log-Warn "OpenClaw 已安装，跳过安装步骤"
} catch {
    Log-Info "正在通过官方脚本安装..."
    try {
        iwr -useb https://openclaw.ai/install.ps1 | iex
    } catch {
        Log-Error "安装失败，请检查网络连接"
        exit 1
    }
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

$openclawVersion = openclaw --version
Log-Info "OpenClaw 版本: $openclawVersion"
Write-Host ""

# 步骤 4/5: 目录创建与权限修复
Log-Step "📁 步骤 4/5: 目录创建与权限修复"
Write-Host "-------------------------------"

$configDir = "$env:USERPROFILE\.openclaw"
$credentialsDir = "$configDir\credentials"
$workspacePath = "$env:USERPROFILE\clawd"

New-Item -ItemType Directory -Force -Path $configDir | Out-Null
New-Item -ItemType Directory -Force -Path $credentialsDir | Out-Null
New-Item -ItemType Directory -Force -Path $workspacePath | Out-Null

icacls $credentialsDir /inheritance:r /grant:r "$env:USERNAME:(OI)(CI)F" | Out-Null
Log-Info "目录已创建，凭据目录权限已设置"
Write-Host ""

# 步骤 5/5: 启动与验证
Log-Step "🚀 步骤 5/5: 启动与验证"
Write-Host "----------------------"

$logFile = "$env:TEMP\openclaw-gateway.log"
Start-Process -FilePath "openclaw" -ArgumentList "gateway", "--port", "18789" -WindowStyle Hidden -RedirectStandardOutput $logFile -RedirectStandardError $logFile
Log-Info "Gateway 已启动（后台运行）"

Log-Info "等待服务启动..."
Start-Sleep -Seconds 5

$pid = Test-Port -Port 18789
if ($pid) {
    Log-Info "Gateway 已启动 (PID: $pid)"
} else {
    Log-Error "Gateway 启动失败，请查看日志: $logFile"
    exit 1
}

Log-Info "运行系统诊断..."
try {
    Invoke-RetryCommand -Command { openclaw doctor } -MaxRetries 3 -TimeoutSeconds 30 | Out-Null
    Log-Info "系统诊断通过"
} catch { Log-Warn "系统诊断失败，但安装已完成" }

Log-Info "运行安全审计..."
try {
    Invoke-RetryCommand -Command { openclaw security audit } -MaxRetries 3 -TimeoutSeconds 30 | Out-Null
    Log-Info "安全审计通过"
} catch { Log-Warn "安全审计失败，但安装已完成" }

Write-Host ""
Write-Host "🎉 OpenClaw 安装完成！" -ForegroundColor Green
Write-Host ""
Write-Host "📝 下一步（由 Claude 自动执行）：" -ForegroundColor Cyan
Write-Host "  1. 生成配置文件 (openclaw.json)"
Write-Host "  2. 配置模型提供商和 API 密钥"
Write-Host "  3. 重启 Gateway 并验证"
Write-Host ""
