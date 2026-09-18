<#
.SYNOPSIS
    创建 DSH 快速启动快捷方式（桌面 + 开始菜单），图标使用鲸鱼娘卡通形象。
.DESCRIPTION
    1) 生成鲸鱼图标 dsh-whale.ico（调用同目录的 New-WhaleIcon.ps1）
    2) 在桌面创建 "DSH 快速启动.lnk"，双击即打开 PowerShell 并运行
       npx @deepseek-ai/dsh web
    3) 默认在桌面不可写时自动请求管理员权限（UAC）
.EXAMPLE
    .\Create-DSH-Shortcut.ps1
    .\Create-DSH-Shortcut.ps1 -Name 'DSH' -AlsoStartMenu
#>
[CmdletBinding()]
param(
    # 快捷方式显示名（不含 .lnk）
    [string]$Name = 'DSH 快速启动',

    # 被指向的启动器，默认同目录的 Launch-DSH-Hidden.vbs（隐藏控制台窗口的桥）
    [string]$Launcher,

    # 图标文件，默认同目录的 dsh-whale.ico
    [string]$IconFile,

    # 端口（写入快捷方式参数，保持与启动脚本一致）
    [int]$Port = 3080,

    # 同时创建到开始菜单
    [switch]$AlsoStartMenu,

    # 桌面不可写时是否尝试提权
    [switch]$NoElevate
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# 路径解析
# ---------------------------------------------------------------------------
$here = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
if (-not $Launcher) { $Launcher = Join-Path $here 'Launch-DSH-Hidden.vbs' }
if (-not $IconFile) { $IconFile = Join-Path $here 'dsh-whale.ico' }

# 兜底：没有 vbs 桥就退回批处理 launch.bat
if (-not (Test-Path -LiteralPath $Launcher)) {
    $candPath = Join-Path $here 'launch.bat'
    if (Test-Path -LiteralPath $candPath) { $Launcher = $candPath }
}
if (-not (Test-Path -LiteralPath $Launcher)) {
    throw "找不到启动器: $Launcher"
}

# ---------------------------------------------------------------------------
# 1. 准备图标
#    优先级：icon-source.png（自己准备的图）> 代码绘制
#    只要源图比 .ico 新就重新转换；否则复用已有的 .ico，绝不白白覆盖。
# ---------------------------------------------------------------------------
$pngScript  = Join-Path $here 'Convert-PngToIcon.ps1'
$drawScript = Join-Path $here 'New-WhaleIcon.ps1'
$iconSource = Join-Path $here 'icon-source.png'

$needBuild = -not (Test-Path -LiteralPath $IconFile)
if (-not $needBuild) {
    if ((Test-Path -LiteralPath $iconSource) -and
        ((Get-Item -LiteralPath $iconSource).LastWriteTime -gt (Get-Item -LiteralPath $IconFile).LastWriteTime)) {
        $needBuild = $true
    }
}

if ($needBuild -and (Test-Path -LiteralPath $iconSource) -and (Test-Path -LiteralPath $pngScript)) {
    Write-Host "[1/3] 正在用 $([System.IO.Path]::GetFileName($iconSource)) 生成图标..." -ForegroundColor Cyan
    & $pngScript -Source $iconSource -OutFile $IconFile | Out-Null
}
elseif ($needBuild -and (Test-Path -LiteralPath $drawScript)) {
    Write-Host '[1/3] 正在绘制鲸鱼娘图标...' -ForegroundColor Cyan
    & $drawScript -OutFile $IconFile | Out-Null
}
elseif (-not (Test-Path -LiteralPath $IconFile)) {
    Write-Host '[!] 没有任何图标来源，将使用系统默认图标。' -ForegroundColor Yellow
    $IconFile = $null
}
else {
    Write-Host '[1/3] 复用已有图标（未改动）。' -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# 2. 定位桌面 / 开始菜单
# ---------------------------------------------------------------------------
$desktop = [Environment]::GetFolderPath('Desktop')
$desktopKnown = [Environment]::GetFolderPath('DesktopDirectory')
if (-not $desktop -and $desktopKnown) { $desktop = $desktopKnown }
if (-not $desktop) { $desktop = Join-Path $env:USERPROFILE 'Desktop' }

$startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'

# ---------------------------------------------------------------------------
# 3. 写快捷方式
# ---------------------------------------------------------------------------
function New-DshShortcut {
    param([string]$LinkPath)

    $shell = New-Object -ComObject WScript.Shell
    try {
        $lnk = $shell.CreateShortcut($LinkPath)

        $ext = [System.IO.Path]::GetExtension($Launcher).ToLowerInvariant()
        if ($ext -eq '.vbs') {
            # 用 wscript 承载 vbs 桥：双击后不闪控制台，直接出现 PowerShell 窗口
            $lnk.TargetPath  = "$env:SystemRoot\System32\wscript.exe"
            $lnk.Arguments   = "`"$Launcher`" $Port"
            $lnk.WindowStyle = 1
        } else {
            # 直接指向 .bat：让 cmd 启动它并立刻退出
            $lnk.TargetPath  = "$env:SystemRoot\System32\cmd.exe"
            $lnk.Arguments   = "/c `"`"$Launcher`"`" --port $Port"
            $lnk.WindowStyle = 7
        }

        $lnk.WorkingDirectory = $env:USERPROFILE
        $lnk.Description      = 'DeepSeek Harness (DSH) 快速启动 - 打开 PowerShell 并运行 npx @deepseek-ai/dsh web'
        if ($IconFile -and (Test-Path -LiteralPath $IconFile)) {
            $lnk.IconLocation = "$IconFile,0"
        }
        $lnk.Save()
    }
    finally {
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
    }
}

Write-Host '[2/3] 正在创建快捷方式...' -ForegroundColor Cyan

# 关键顺序：先在「本目录」生成一个权威的 .lnk，再往桌面/开始菜单复制。
#
# 以前是先写桌面，失败才退到本目录，而那个退路又被 $needElevate 的状态
# 判断挡住，导致桌面写不进去时本目录也没生成，却照样打印"完成" ——
# 调用方于是永远拿不到可用的源快捷方式，桌面上还留着指向旧目录的坏链接。
# 现在改为"先本地、后复制"，任何一步失败都能如实反映。
$localLink = Join-Path $here "$Name.lnk"
$localOk = $false
try {
    New-DshShortcut -LinkPath $localLink
    $localOk = Test-Path -LiteralPath $localLink
}
catch {
    Write-Host "[!] 本地生成快捷方式失败: $($_.Exception.Message)" -ForegroundColor Yellow
}
if ($localOk) {
    Write-Host "      已生成本地快捷方式: $localLink" -ForegroundColor DarkGray
} else {
    Write-Host "[!] 未能在本目录生成快捷方式。" -ForegroundColor Yellow
}

$link = $localLink

# ---- 复制到桌面 ---------------------------------------------------------
$desktopLink = Join-Path $desktop "$Name.lnk"
$desktopOk = $false

if ($localOk) {
    # 先清掉目标位置的旧文件：桌面若躺着一个指向已删目录的坏快捷方式，
    # 不删掉的话复制/覆盖都可能被拒，而且会一直被当成"已经装好了"。
    if (Test-Path -LiteralPath $desktopLink) {
        try { Remove-Item -LiteralPath $desktopLink -Force -ErrorAction Stop }
        catch { Write-Host "[!] 无法删除桌面上已有的旧快捷方式: $($_.Exception.Message)" -ForegroundColor Yellow }
    }

    try {
        Copy-Item -LiteralPath $localLink -Destination $desktopLink -Force -ErrorAction Stop
        $desktopOk = $true
    }
    catch {
        Write-Host "[!] 桌面写入失败: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    if (-not $desktopOk -and -not $NoElevate) {
        Write-Host '[i] 尝试以管理员身份重试（会弹出 UAC，请点“是”）...' -ForegroundColor Yellow
        try {
            $elevArgs = @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass',
                '-File', "`"$PSCommandPath`"",
                '-Name', "`"$Name`"",
                '-Launcher', "`"$Launcher`"",
                '-Port', "$Port",
                '-NoElevate'
            )
            if ($IconFile) { $elevArgs += @('-IconFile', "`"$IconFile`"") }
            # 提权进程负责复制桌面那一步，这里不需要 -DesktopOnly，重复无害
            Start-Process -FilePath 'powershell.exe' -ArgumentList $elevArgs -Verb RunAs -Wait -ErrorAction Stop
            for ($i = 0; $i -lt 8 -and -not $desktopOk; $i++) {
                Start-Sleep -Milliseconds 250
                $desktopOk = Test-Path -LiteralPath $desktopLink
            }
        }
        catch {
            Write-Host "[!] 提权被取消或失败: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

if ($AlsoStartMenu) {
    $smLink = Join-Path $startMenu "$Name.lnk"
    if ($localOk) {
        try {
            Copy-Item -LiteralPath $localLink -Destination $smLink -Force -ErrorAction Stop
            Write-Host "      开始菜单: $smLink" -ForegroundColor DarkGray
        }
        catch { Write-Host "[!] 开始菜单快捷方式创建失败: $($_.Exception.Message)" -ForegroundColor Yellow }
    }
}

# ---------------------------------------------------------------------------
# 4. 汇报（如实反映每一步的结果）
# ---------------------------------------------------------------------------
Write-Host '[3/3] 完成' -ForegroundColor Cyan
Write-Host ''
Write-Host "  本地快捷方式 : $localLink" -ForegroundColor $(if ($localOk) { 'White' } else { 'Red' })
Write-Host "  桌面快捷方式 : $desktopLink" -ForegroundColor $(if ($desktopOk) { 'White' } else { 'Yellow' })
Write-Host "  启动器       : $Launcher" -ForegroundColor White
Write-Host "  图标         : $IconFile" -ForegroundColor White
Write-Host "  Web UI       : http://127.0.0.1:$Port" -ForegroundColor White
Write-Host ''
if ($desktopOk) {
    Write-Host '  已在桌面创建完成，双击即可运行 npx @deepseek-ai/dsh web' -ForegroundColor Green
} elseif ($localOk) {
    Write-Host '  桌面写入未成功，但本地快捷方式已生成，可手动复制到桌面：' -ForegroundColor Yellow
    Write-Host "    $localLink" -ForegroundColor Yellow
} else {
    Write-Host '  快捷方式未能生成，请以管理员身份重新运行本脚本。' -ForegroundColor Red
}
Write-Host ''
