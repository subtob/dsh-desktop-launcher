<#
.SYNOPSIS
    在 PowerShell 窗口里启动 DeepSeek Harness 的 Web UI（npx @deepseek-ai/dsh web）
.EXAMPLE
    .\Launch-DSH.ps1
    .\Launch-DSH.ps1 -Port 3080 -NoOpen
#>
[CmdletBinding()]
param(
    # Web UI 监听端口
    [int]$Port = 3080,

    # 绑定地址（保持 127.0.0.1 本机回环，不要改成 0.0.0.0）
    [string]$BindHost = '127.0.0.1',

    # 启动后自己不去打开浏览器（交给快捷方式/批处理打开）
    [switch]$NoOpen,

    # npx 包名，一般不用改
    [string]$Package = '@deepseek-ai/dsh'
)

$ErrorActionPreference = 'Stop'
$uiUrl = "http://${BindHost}:${Port}"

# ---- 让控制台正确显示中文并带上标题 -------------------------------------
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $Host.UI.RawUI.WindowTitle = "DSH - DeepSeek Harness  ($uiUrl)"
} catch { }

Write-Host ''
Write-Host '  ============================================================' -ForegroundColor DarkCyan
Write-Host '    DeepSeek Harness (DSH) 快速启动' -ForegroundColor Cyan
Write-Host "    地址: $uiUrl" -ForegroundColor Cyan
Write-Host '    停止: 在本窗口按 Ctrl + C，或直接关闭窗口' -ForegroundColor DarkGray
Write-Host '  ============================================================' -ForegroundColor DarkCyan
Write-Host ''

# ---- 检查 npx 是否可用 ---------------------------------------------------
$npxExe = $null
foreach ($name in @('npx.cmd', 'npx.exe', 'npx')) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { $npxExe = $cmd.Source; break }
}
if (-not $npxExe) {
    Write-Host '[x] 找不到 npx，请先安装 Node.js (https://nodejs.org)。' -ForegroundColor Red
    Write-Host '    安装后重新打开本窗口即可。' -ForegroundColor Yellow
    return
}

# ---- 端口校验 ------------------------------------------------------------
if ($Port -lt 0 -or $Port -gt 65535) {
    Write-Host "[x] 端口号非法: $Port（应为 0-65535）" -ForegroundColor Red
    return
}

# ---- 端口被占用时不再重复启动 -------------------------------------------
# 探测失败（权限不足 / 系统精简）一律当作「未占用」，
# 绝不能让一个探测动作本身挡住启动。
function Test-PortBusy {
    param([int]$P)

    if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
        try {
            $r = @(Get-NetTCPConnection -LocalPort $P -State Listen -ErrorAction Stop)
            return ($r.Count -gt 0)
        } catch { }
    }

    if (Get-Command netstat.exe -ErrorAction SilentlyContinue) {
        try {
            $hit = netstat -ano -p TCP 2>$null |
                Select-String -SimpleMatch ":$P " |
                Where-Object { $_.Line -match 'LISTENING' }
            return ($null -ne $hit)
        } catch { }
    }

    return $false
}

if (Test-PortBusy -P $Port) {
    Write-Host "[i] 端口 $Port 已被占用，DSH 可能已经在运行。" -ForegroundColor Yellow
    Write-Host "[i] 直接打开 $uiUrl" -ForegroundColor Yellow
    if (-not $NoOpen) {
        try { Start-Process $uiUrl } catch { Write-Host "[!] 打开浏览器失败: $($_.Exception.Message)" -ForegroundColor Red }
    }
    return
}

# ---- 正式启动 -----------------------------------------------------------
$dshArgs = @($Package, 'web', '--port', "$Port", '--host', $BindHost)
if ($NoOpen) { $dshArgs += '--no-open' }

Write-Host "  > npx $($dshArgs -join ' ')" -ForegroundColor Green
Write-Host ''

& $npxExe @dshArgs
[int]$code = -1
if ($null -ne $LASTEXITCODE) { $code = $LASTEXITCODE }

Write-Host ''
if ($code -eq 0) {
    Write-Host '[i] DSH 已退出。' -ForegroundColor DarkGray
} else {
    Write-Host "[x] DSH 未能启动或异常退出，退出码 $code。" -ForegroundColor Red
    Write-Host '    若提示网络错误，请检查网络后按 ↑ 回车重试。' -ForegroundColor Yellow
}
