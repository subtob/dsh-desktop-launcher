<#
.SYNOPSIS
    把 DSH 快捷方式安装到桌面 / 开始菜单，并写出诊断日志。
.DESCRIPTION
    纯 ASCII 的 .bat 只是外壳，真正的路径与中文名处理都放在这里，
    因为 PowerShell 能正确读取 UTF-8 脚本，而 cmd.exe 会按 GBK 误读。

    每一步都会打印结果，并追加写入 Install-Log.txt，
    即使窗口一闪而过也能从日志里查到失败原因。
#>
[CmdletBinding()]
param(
    # 快捷方式显示名
    [string]$Name = 'DSH 快速启动',

    # 源 .lnk（本目录下已生成好的快捷方式）
    [string]$SourceLink,

    # 同时装到开始菜单
    [switch]$StartMenu,

    # 不打印 pause 提示
    [switch]$Quiet,

    # 不在失败时申请管理员权限（提权后递归调用用得到）
    [switch]$SkipElevate,

    # 换成你自己准备的图片（png/jpg），会自动转成多尺寸 .ico
    [string]$IconSource
)

$ErrorActionPreference = 'Continue'

$here = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$log  = Join-Path $here 'Install-Log.txt'

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line  = "[$stamp] [$Level] $Message"
    try { Add-Content -LiteralPath $log -Value $line -Encoding UTF8 } catch { }
    switch ($Level) {
        'ERROR' { Write-Host $Message -ForegroundColor Red }
        'WARN'  { Write-Host $Message -ForegroundColor Yellow }
        'OK'    { Write-Host $Message -ForegroundColor Green }
        default { Write-Host $Message }
    }
}

function Test-LinkReady {
    <#
      可靠地判断快捷方式是不是真的建好了。

      不能用单一的 Test-Path 就下结论：在部分环境里（沙箱、按需加载的
      虚拟磁盘、杀软实时扫描、落盘延迟）文件刚写完的那一瞬间 Test-Path
      可能返回 false，于是明明建成功却被报成失败 —— 这正是本脚本曾经的 bug。

      这里改用「重试 + 多重独立证据」：
        a) 有文件、且长度大于 0
        b) 能通过 Shell 打开，且 TargetPath 非空（说明是有效快捷方式）
    #>
    param([string]$Path, [int]$Retries = 8)

    if (-not $Path) { return $false }
    for ($i = 0; $i -lt $Retries; $i++) {
        try {
            $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
            if ($item.Length -gt 0) {
                $sh = New-Object -ComObject WScript.Shell
                try {
                    $lnk = $sh.CreateShortcut($Path)
                    if ($lnk.TargetPath) { return $true }
                }
                finally { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($sh) }
            }
        }
        catch { }
        Start-Sleep -Milliseconds 250
    }
    return $false
}

try { Set-Content -LiteralPath $log -Value "=== DSH shortcut install log ===" -Encoding UTF8 } catch { }

Write-Host ''
Write-Log 'DSH 快捷方式安装程序' 'INFO'
Write-Log "脚本目录 : $here"
Write-Log "脚本宿主 : PowerShell $($PSVersionTable.PSVersion)"

# ---- 0. 如果要换图标，先把新图片就位 ------------------------------------
if ($IconSource) {
    if (Test-Path -LiteralPath $IconSource) {
        $dstPng = Join-Path $here 'icon-source.png'
        try {
            Copy-Item -LiteralPath $IconSource -Destination $dstPng -Force -ErrorAction Stop
            Write-Log "图标源已更新: $IconSource" 'OK'
        }
        catch {
            Write-Log "复制图标源失败: $($_.Exception.Message)" 'ERROR'
        }
    }
    else {
        Write-Log "找不到图标源文件: $IconSource" 'ERROR'
    }
}

# ---- 1. 确保源快捷方式存在，并且是「好的」 -------------------------------
if (-not $SourceLink) { $SourceLink = Join-Path $here 'DSH 快速启动.lnk' }

# 一个快捷方式"能用"不只是文件存在，更要看它指向的东西还在不在。
# 否则会把一个「指向已删除目录」的坏快捷方式当成好的复制来复制去 ——
# 结果就是桌面图标变白、双击报"找不到"。这个坑本项目真实踩过。
function Test-LinkUsable {
    param([string]$Path, [int]$Retries = 2)

    if (-not (Test-LinkReady -Path $Path -Retries $Retries)) { return $false }
    try {
        $sh = New-Object -ComObject WScript.Shell
        try { $lnk = $sh.CreateShortcut($Path) }
        finally { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($sh) }

        if (-not (Test-Path -LiteralPath $lnk.TargetPath)) { return $false }

        # 参数里引号包着的那个脚本也要在（如 ...vbs" 3080）
        if ($lnk.Arguments -match '^"([^"]+)"') {
            if (-not (Test-Path -LiteralPath $Matches[1])) { return $false }
        }

        # 图标字段指向的文件也要在，否则桌面会显示白色图标
        $iconPath = ($lnk.IconLocation -replace ',\s*-?\d+$', '').Trim()
        if ($iconPath -and -not (Test-Path -LiteralPath $iconPath)) { return $false }

        return $true
    }
    catch { return $false }
}

# 桌面上若已有一个「真正可用」的快捷方式，直接复用它最省事
function Test-ExistingTargetLink {
    $desk = [Environment]::GetFolderPath('Desktop')
    if (-not $desk) { $desk = Join-Path $env:USERPROFILE 'Desktop' }
    $cands = @(
        (Join-Path $desk "$Name.lnk"),
        (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$Name.lnk")
    )
    foreach ($c in $cands) {
        if (Test-LinkUsable -Path $c) { return $c }
    }
    return $null
}

if (Test-Path -LiteralPath $SourceLink) {
    if (-not (Test-LinkUsable -Path $SourceLink)) {
        Write-Log "本目录的快捷方式已失效（指向的文件不存在），将重新生成: $SourceLink" 'WARN'
        Remove-Item -LiteralPath $SourceLink -Force -ErrorAction SilentlyContinue
    }
}

if (-not (Test-LinkUsable -Path $SourceLink)) {
    # 本目录没有可用的 .lnk，先看桌面上有没有「真正可用」的可以复用
    $existing = Test-ExistingTargetLink
    if ($existing) {
        Write-Log "复用桌面上已有的可用快捷方式: $existing" 'OK'
        $SourceLink = $existing
    }
    else {
        # 没有可复用的，就老老实实重新生成一个（指向当前的启动器与图标）
        $maker = Join-Path $here 'Create-DSH-Shortcut.ps1'
        if (Test-Path -LiteralPath $maker) {
            Write-Log '正在重新生成快捷方式（指向当前目录的启动器与图标）...'
            & $maker -Name $Name -NoElevate | Out-Null
        }
        else {
            Write-Log "缺少 Create-DSH-Shortcut.ps1，无法生成快捷方式。" 'ERROR'
        }
    }
}

if (Test-LinkUsable -Path $SourceLink) {
    Write-Log "源文件 OK : $SourceLink"
} else {
    Write-Log "仍然没有可用的快捷方式: $SourceLink" 'ERROR'
    Write-Log '请确认 Create-DSH-Shortcut.ps1 与本脚本在同一目录。' 'ERROR'
}

# ---- 2. 复制到桌面 / 开始菜单 -------------------------------------------
function Install-Link {
    param([string]$TargetPath, [string]$Label)

    $dir = Split-Path -Parent $TargetPath
    if (-not (Test-Path -LiteralPath $dir)) {
        Write-Log "$Label 目录不存在: $dir" 'ERROR'
        return $false
    }

    # 源和目标是同一个文件时不必复制（例如源本来就是桌面上的那个），
    # 否则 Copy-Item 会抛 "cannot overwrite the item with itself" 这种假报错
    $srcFull = try { [System.IO.Path]::GetFullPath($SourceLink) } catch { $SourceLink }
    $dstFull = try { [System.IO.Path]::GetFullPath($TargetPath) } catch { $TargetPath }
    if ($srcFull -ieq $dstFull) {
        if (Test-LinkUsable -Path $TargetPath) {
            Write-Log "$Label 已在目标位置就位，无需复制: $TargetPath" 'OK'
            return $true
        }
    }

    # 目标位置的旧文件（可能是坏的，例如指向已删除的目录）必须先删掉，
    # 否则覆盖会失败，而一个"看起来存在"的坏链接会一直被误判为已安装
    if (Test-Path -LiteralPath $TargetPath) {
        if (-not (Test-LinkUsable -Path $TargetPath)) {
            Write-Log "$Label 检测到已有失效的快捷方式（指向的文件不存在），先删除它。" 'WARN'
            Remove-Item -LiteralPath $TargetPath -Force -ErrorAction SilentlyContinue
        }
    }

    $copied = $false
    try {
        Copy-Item -LiteralPath $SourceLink -Destination $TargetPath -Force -ErrorAction Stop
        $copied = $true
    }
    catch {
        Write-Log "$Label 复制未成功: $($_.Exception.Message)" 'WARN'
    }

    # 不管复制有没有报错，都实际验证一次：报错也可能只是"假失败"。
    # 但"能用"必须包含"它指向的东西还在"，否则桌面会变成白色图标 + 双击报错。
    if (Test-LinkUsable -Path $TargetPath) {
        if ($copied) {
            Write-Log "$Label 安装成功: $TargetPath" 'OK'
        }
        else {
            # 已经有一个可用的快捷方式，但这次没能覆盖它，
            # 所以无法保证它是最新的 —— 必须如实说明，不能报"成功"。
            Write-Log "$Label 位置已存在一个可用的快捷方式（可能是旧版本，本次未能覆盖）: $TargetPath" 'WARN'
            Write-Log "  如需刷新它，请以管理员身份重新运行本脚本。" 'WARN'
        }
        return $true
    }
    Write-Log "$Label 未能在目标位置生成可用的快捷方式。" 'ERROR'
    return $false
}

$desktop = [Environment]::GetFolderPath('Desktop')
if (-not $desktop) { $desktop = Join-Path $env:USERPROFILE 'Desktop' }
Write-Log "桌面目录 : $desktop"

$ok = $false
$desktopLink = Join-Path $desktop "$Name.lnk"
if (Test-Path -LiteralPath $SourceLink) {
    $ok = Install-Link -TargetPath $desktopLink -Label '桌面'

    if (-not $ok) {
        # 退路：直接当场重建一个，绕开文件复制权限问题
        Write-Log '改用“直接重建快捷方式”方式重试...' 'WARN'
        $maker = Join-Path $here 'Create-DSH-Shortcut.ps1'
        if (Test-Path -LiteralPath $maker) {
            & $maker -Name $Name -NoElevate | Out-Null
            $ok = Test-LinkUsable -Path $desktopLink
            if ($ok) { Write-Log '重建后桌面快捷方式已就位。' 'OK' }
        }
    }

    if (-not $ok -and -not $SkipElevate) {
        # 退路 2：桌面被权限/组策略锁定时，申请管理员权限（会弹 UAC）
        Write-Log '尝试申请管理员权限重试（会弹出 UAC 窗口，请点“是”）...' 'WARN'
        try {
            $elevArgs = @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass',
                '-File', "`"$PSCommandPath`"",
                '-Name', "`"$Name`"",
                '-Quiet', '-SkipElevate'
            )
            if ($StartMenu) { $elevArgs += '-StartMenu' }
            Start-Process -FilePath 'powershell.exe' -ArgumentList $elevArgs -Verb RunAs -Wait -ErrorAction Stop

            # 提权进程是在另一个进程里写的，落盘可能稍慢，这里多等一会
            $ok = Test-LinkUsable -Path $desktopLink -Retries 20
            if ($ok) { Write-Log '提权后桌面快捷方式已就位。' 'OK' }
            else { Write-Log '提权后仍未能创建，请右键本脚本选择“以管理员身份运行”再试。' 'ERROR' }
        }
        catch {
            Write-Log "提权失败或被取消: $($_.Exception.Message)" 'ERROR'
        }
    }

    if ($StartMenu) {
        $sm = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
        if (Test-Path -LiteralPath $sm) {
            [void](Install-Link -TargetPath (Join-Path $sm "$Name.lnk") -Label '开始菜单')
        } else {
            Write-Log "开始菜单目录不存在: $sm" 'WARN'
        }
    }
}

# ---- 3. 汇报 -------------------------------------------------------------
# 不轻信中间变量，最终按「能不能真的用」重新确认一次：
# 文件存在、目标脚本存在、图标存在，三者齐全才算好。
$desktopLinkOk = Test-LinkUsable -Path $desktopLink -Retries 4
$localOut = Join-Path $here "$Name.lnk"
$localOutOk = Test-LinkUsable -Path $localOut -Retries 2

if ($desktopLinkOk) { $ok = $true }

Write-Host ''
if ($desktopLinkOk) {
    Write-Log '成功：桌面快捷方式已可用。' 'OK'
    Write-Log "  $desktopLink" 'OK'
    Write-Log '若桌面上暂时看不到，按 F5 刷新一次。' 'OK'
}
elseif ($localOutOk) {
    Write-Log '桌面写入未成功，但本目录已生成可用的快捷方式：' 'WARN'
    Write-Log "  $localOut" 'WARN'
    Write-Log '你可以手动把它复制到桌面，或以管理员身份重跑「创建快捷方式.bat」。' 'WARN'
}
else {
    Write-Log "快捷方式未能生成：$desktopLink" 'ERROR'
    Write-Log '请右键「创建快捷方式.bat」选择“以管理员身份运行”再试一次，' 'ERROR'
    Write-Log '或把 Install-Log.txt 的内容发给我。' 'ERROR'
}
Write-Log "日志文件 : $log"
Write-Host ''
