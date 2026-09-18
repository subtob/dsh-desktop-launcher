<#
.SYNOPSIS
    把任意 PNG/JPG 图片转换成多尺寸 Windows .ico 图标。
.DESCRIPTION
    1) 每个尺寸都从「原始全分辨率图片」直接缩放，避免逐级缩放糊掉细节
    2) 紫色调的抗锯齿边缘可能带有「白色雾边」（旧版看是白底造成的），
       本脚本按 颜色/亮度 加权把发白的半透明像素的 alpha 拉回来，
       这样在深色任务栏上也不会出现白边
    3) 统一写入方形画布，四周留出内边距，缩到 16px 时不会顶到边框
.NOTES
    纯 System.Drawing 实现，不依赖任何第三方库。
.EXAMPLE
    .\Convert-PngToIcon.ps1 -Source '.\icon-source.png' -OutFile '.\dsh-whale.ico'
#>
[CmdletBinding()]
param(
    # 源图片
    [Parameter(Mandatory = $true)]
    [string]$Source,

    # 输出 ico
    [Parameter(Mandatory = $true)]
    [string]$OutFile,

    # 生成的尺寸
    [int[]]$Sizes = @(16, 24, 32, 48, 64, 128, 256),

    # 画布内边距比例（0.04 = 四周各留 4%）
    [double]$Padding = 0.04,

    # 是否清理发白的半透明边缘
    [switch]$NoDeFringe
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# ---------------------------------------------------------------------------
# 去白边：把「亮且饱和度过低」的半透明像素视为背景残留，压低其 alpha
# ---------------------------------------------------------------------------
function Remove-WhiteFringe {
    param([System.Drawing.Bitmap]$Bitmap)

    $w = $Bitmap.Width
    $h = $Bitmap.Height
    $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
    $data = $Bitmap.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $bytes = $data.Stride * $h
        $buf = New-Object byte[] $bytes
        [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $buf, 0, $bytes)

        for ($i = 0; $i -lt $bytes; $i += 4) {
            $a = $buf[$i + 3]
            if ($a -eq 0 -or $a -eq 255) { continue }   # 全透明/全不透明不动

            $b = $buf[$i]
            $g = $buf[$i + 1]
            $r = $buf[$i + 2]

            $max = [Math]::Max($r, [Math]::Max($g, $b))
            $min = [Math]::Min($r, [Math]::Min($g, $b))
            $sat = $max - $min                 # 0..255，越低越接近灰白

            # 越白且越不饱和，越可能是白色背景的抗锯齿残留
            if ($sat -lt 30 -and $max -gt 200) {
                $whiteness = (($max - 200) / 55.0) * ((30 - $sat) / 30.0)
                if ($whiteness -gt 0) {
                    $factor = 1.0 - (0.85 * $whiteness)
                    $buf[$i + 3] = [byte][Math]::Round($a * $factor)
                }
            }
        }

        [System.Runtime.InteropServices.Marshal]::Copy($buf, 0, $data.Scan0, $bytes)
    }
    finally {
        $Bitmap.UnlockBits($data)
    }
}

# ---------------------------------------------------------------------------
# 从源图渲染一个尺寸
# ---------------------------------------------------------------------------
function New-IconBitmap {
    param([System.Drawing.Image]$Src, [int]$Size, [double]$Pad)

    $canvas = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($canvas)
    try {
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.SmoothingMode        = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.InterpolationMode    = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode      = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.CompositingQuality   = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

        # 保持长宽比，按「内边距」缩放到方形画布内
        $inner = $Size * (1.0 - (2 * $Pad))
        $scale = [Math]::Min($inner / $Src.Width, $inner / $Src.Height)
        $dw = [int][Math]::Round($Src.Width * $scale)
        $dh = [int][Math]::Round($Src.Height * $scale)
        $dx = [int][Math]::Round(($Size - $dw) / 2)
        $dy = [int][Math]::Round(($Size - $dh) / 2)

        $destRect = New-Object System.Drawing.Rectangle($dx, $dy, $dw, $dh)
        $g.DrawImage($Src, $destRect, 0, 0, $Src.Width, $Src.Height, [System.Drawing.GraphicsUnit]::Pixel)
    }
    finally { $g.Dispose() }
    return $canvas
}

# ---------------------------------------------------------------------------
# 组装 ICO（每帧写 PNG 数据，Vista+ 原生支持）
# ---------------------------------------------------------------------------
function Write-IconFile {
    param([string]$Path, [System.Collections.ArrayList]$Frames)

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $fs = [System.IO.File]::Create($Path)
    $bw = New-Object System.IO.BinaryWriter($fs)
    try {
        $bw.Write([uint16]0)                  # reserved
        $bw.Write([uint16]1)                  # type = icon
        $bw.Write([uint16]$Frames.Count)      # frame count

        $offset = 6 + (16 * $Frames.Count)
        foreach ($f in $Frames) {
            $dim = if ($f.Size -ge 256) { 0 } else { $f.Size }
            $bw.Write([byte]$dim)             # width
            $bw.Write([byte]$dim)             # height
            $bw.Write([byte]0)                # palette count
            $bw.Write([byte]0)                # reserved
            $bw.Write([uint16]1)              # color planes
            $bw.Write([uint16]32)             # bits per pixel
            $bw.Write([uint32]$f.Bytes.Length)
            $bw.Write([uint32]$offset)
            $offset += $f.Bytes.Length
        }
        foreach ($f in $Frames) { $bw.Write($f.Bytes) }
    }
    finally {
        $bw.Flush(); $bw.Dispose(); $fs.Dispose()
    }
}

# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
$Source = (Resolve-Path -LiteralPath $Source).Path
Write-Host "源图片 : $Source" -ForegroundColor DarkGray

# 先在原始分辨率上做去白边，再拿去缩放（缩放后不易判断阈值）
$master = New-Object System.Drawing.Bitmap($Source)
if (-not $NoDeFringe) {
    Write-Host '正在清理发白的半透明边缘...' -ForegroundColor DarkGray
    Remove-WhiteFringe -Bitmap $master
}

$frames = New-Object System.Collections.ArrayList
foreach ($s in ($Sizes | Sort-Object -Unique)) {
    $bmp = New-IconBitmap -Src $master -Size $s -Pad $Padding
    $ms = New-Object System.IO.MemoryStream
    try {
        $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        [void]$frames.Add(@{ Size = $s; Bytes = $ms.ToArray() })
    }
    finally { $ms.Dispose(); $bmp.Dispose() }
}
$master.Dispose()

Write-IconFile -Path $OutFile -Frames $frames

$info = Get-Item -LiteralPath $OutFile
Write-Host ("已生成图标: {0}  ({1} 帧, {2:N0} 字节)" -f $info.FullName, $frames.Count, $info.Length) -ForegroundColor Cyan
