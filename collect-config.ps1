# OpenClaw 配置收集脚本 (Windows PowerShell)
# 用于快速收集部署所需的所有信息
# 版本: 4.3

$ErrorActionPreference = "Stop"

# 颜色函数
function Write-Info { param([string]$Message); Write-Host "[INFO] $Message" -ForegroundColor Blue }
function Write-Success { param([string]$Message); Write-Host "[✓] $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message); Write-Host "[!] $Message" -ForegroundColor Yellow }
function Write-Error { param([string]$Message); Write-Host "[✗] $Message" -ForegroundColor Red }

# 配置文件路径
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutputFile = "$env:USERPROFILE\.openclaw\deployment-config.json"
$ProviderRegistry = "$ScriptDir\provider-registry.json"

# 创建输出目录
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.openclaw" | Out-Null

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  OpenClaw 配置收集向导 v4.3" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# 1. 检测操作系统
Write-Info "检测操作系统..."
$OS = "windows"
Write-Success "操作系统: $OS"

# 2. 选择模型提供商
Write-Host ""
Write-Info "选择模型提供商:"
Write-Host "  1) Kimi (Moonshot) - 推荐"
Write-Host "  2) Minimax"
Write-Host "  3) Ollama (本地/局域网)"
Write-Host "  4) 自定义 OpenAI 兼容"
Write-Host "  5) 自定义 Anthropic 兼容"
$providerChoice = Read-Host "请选择 [1-5]"

switch ($providerChoice) {
    "1" { $Provider = "kimi" }
    "2" { $Provider = "minimax" }
    "3" { $Provider = "ollama" }
    "4" { $Provider = "custom-openai" }
    "5" { $Provider = "custom-anthropic" }
    default { Write-Error "无效选择"; exit 1 }
}

# 3. 收集主模型配置
Write-Host ""
Write-Info "配置主模型..."

if ($Provider -eq "ollama") {
    $OllamaServer = Read-Host "请输入 Ollama 服务器地址 [127.0.0.1:11434]"
    if ([string]::IsNullOrWhiteSpace($OllamaServer)) { $OllamaServer = "127.0.0.1:11434" }
    $ModelId = Read-Host "请输入模型名称 [qwen:7b]"
    if ([string]::IsNullOrWhiteSpace($ModelId)) { $ModelId = "qwen:7b" }
    $BaseUrl = "http://$OllamaServer/v1"
    $ApiKey = "ollama"

    # 代理检测
    $ProxyDetected = Get-ChildItem Env: | Where-Object { $_.Name -match 'proxy' } | Select-Object -First 1
    if ($ProxyDetected -and $OllamaServer -notmatch '^127\.0\.0\.1' -and $OllamaServer -notmatch '^localhost') {
        Write-Host ""
        Write-Warn "检测到系统代理: $($ProxyDetected.Name)=$($ProxyDetected.Value)"
        Write-Warn "OpenClaw 的 HTTP 客户端不支持 NO_PROXY，LAN IP 连接会失败！"
        Write-Warn "建议：使用 SSH 隧道将远程端口映射到 localhost"
        Write-Host "   ssh -f -N -L 11434:localhost:11434 user@<server-ip>"
        Write-Host "   然后服务器地址填 127.0.0.1:11434"
        Write-Host ""
        $sshTunnelReady = Read-Host "是否已设置 SSH 隧道？[y/N]"
        if ($sshTunnelReady -notmatch "^[Yy]$") {
            Write-Warn "请先设置 SSH 隧道后再继续"
        }
    }
} elseif ($Provider -eq "custom-openai" -or $Provider -eq "custom-anthropic") {
    $BaseUrl = Read-Host "请输入 baseUrl"
    $ModelId = Read-Host "请输入模型 ID"
    $ApiKey = Read-Host "请输入 API Key"
} else {
    $BaseUrl = ""
    $ModelId = ""
    $ApiKey = Read-Host "请输入 API Key"
}

# 4. 询问是否需要 fallback
Write-Host ""
$needFallback = Read-Host "是否配置备用模型? [y/N]"
if ($needFallback -match "^[Yy]$") {
    if ($Provider -eq "kimi") {
        Write-Host "  1) Minimax - 推荐"
        Write-Host "  2) 不需要"
        $fallbackChoice = Read-Host "选择备用模型 [1-2]"

        switch ($fallbackChoice) {
            "1" { $FallbackProvider = "minimax" }
            default { $FallbackProvider = "" }
        }
    } elseif ($Provider -eq "minimax") {
        Write-Host "  1) Kimi (Moonshot) - 推荐"
        Write-Host "  2) 不需要"
        $fallbackChoice = Read-Host "选择备用模型 [1-2]"

        switch ($fallbackChoice) {
            "1" { $FallbackProvider = "kimi" }
            default { $FallbackProvider = "" }
        }
    } else {
        Write-Host "  1) Kimi (Moonshot) - 推荐"
        Write-Host "  2) Minimax"
        Write-Host "  3) 不需要"
        $fallbackChoice = Read-Host "选择备用模型 [1-3]"

        switch ($fallbackChoice) {
            "1" { $FallbackProvider = "kimi" }
            "2" { $FallbackProvider = "minimax" }
            default { $FallbackProvider = "" }
        }
    }

    if ($FallbackProvider) {
        $FallbackApiKey = Read-Host "请输入备用模型的 API Key"
    } else {
        $FallbackApiKey = ""
    }
} else {
    $FallbackProvider = ""
    $FallbackApiKey = ""
}

# 5. 询问是否需要飞书
Write-Host ""
$needFeishu = Read-Host "是否需要飞书集成? [y/N]"
if ($needFeishu -match "^[Yy]$") {
    $FeishuEnabled = "true"
    $FeishuAppId = Read-Host "飞书 App ID (可稍后提供，直接回车跳过)"
    $FeishuAppSecret = Read-Host "飞书 App Secret (可稍后提供，直接回车跳过)"
} else {
    $FeishuEnabled = "false"
    $FeishuAppId = ""
    $FeishuAppSecret = ""
}

# 6. 生成配置 JSON
Write-Host ""
Write-Info "生成配置文件..."

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$fallbackEnabled = if ($FallbackProvider) { "true" } else { "false" }
$ollamaServerField = if ($Provider -eq "ollama") { ",`n    `"ollamaServer`": `"$OllamaServer`"" } else { "" }

$config = @"
{
  "timestamp": "$timestamp",
  "os": "$OS",
  "provider": {
    "name": "$Provider",
    "baseUrl": "$BaseUrl",
    "modelId": "$ModelId",
    "apiKey": "$ApiKey"$ollamaServerField
  },
  "fallback": {
    "enabled": $fallbackEnabled,
    "provider": "$FallbackProvider",
    "apiKey": "$FallbackApiKey"
  },
  "feishu": {
    "enabled": $FeishuEnabled,
    "appId": "$FeishuAppId",
    "appSecret": "$FeishuAppSecret"
  }
}
"@

$config | Out-File -FilePath $OutputFile -Encoding UTF8
Write-Success "配置已保存到: $OutputFile"

# 7. 显示摘要
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  配置摘要" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "操作系统:     $OS"
Write-Host "主模型:       $Provider"
Write-Host "备用模型:     $(if ($FallbackProvider) { $FallbackProvider } else { '无' })"
Write-Host "飞书集成:     $(if ($FeishuEnabled -eq 'true') { '是' } else { '否' })"
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Success "配置收集完成！现在可以运行 /openclaw-remote-deploy 开始部署"
Write-Host ""
