<#
.SYNOPSIS
    生成 DeepSeek 鲸鱼娘卡通形象的 .ico 图标
.DESCRIPTION
    使用 System.Drawing (GDI+) 纯代码绘制一只可爱的蓝色鲸鱼（鲸鱼娘风格），
    不依赖任何外部图片素材，输出多尺寸 ICO 文件。
.NOTES
    可单独运行，也可被 Create-DSH-Shortcut.ps1 调用。
#>
[CmdletBinding()]
param(
    # 输出 ico 路径
    [string]$OutFile = (Join-Path $PSScriptRoot 'dsh-whale.ico'),

    # ico 中包含的尺寸
    [int[]]$Sizes = @(16, 32, 48, 64, 128, 256)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

# ---------------------------------------------------------------------------
# 画布尺寸：内部统一按 256x256 的坐标系作画，再整体缩放
# ---------------------------------------------------------------------------
$Master = 256.0

function New-Brush  { param([string]$Hex) New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($Hex)) }
function New-Pen    { param([string]$Hex, [double]$W) New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml($Hex)), ([single]$W) }

function Add-RoundRectPath {
    param(
        [System.Drawing.Drawing2D.GraphicsPath]$Path,
        [single]$X, [single]$Y, [single]$W, [single]$H, [single]$R
    )
    if ($R -le 0) { $Path.AddRectangle([System.Drawing.RectangleF]::new($X, $Y, $W, $H)); return }
    $d = $R * 2
    $Path.AddArc($X, $Y, $d, $d, 180, 90)
    $Path.AddArc($X + $W - $d, $Y, $d, $d, 270, 90)
    $Path.AddArc($X + $W - $d, $Y + $H - $d, $d, $d, 0, 90)
    $Path.AddArc($X, $Y + $H - $d, $d, $d, 90, 90)
    $Path.CloseFigure()
}

function Add-Eye {
    param([System.Drawing.Graphics]$G, [single]$X, [single]$Y, [single]$Scale = 1.0)
    $ink = [System.Drawing.ColorTranslator]::FromHtml('#1B2A4A')
    $w  = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
    $p  = New-Object System.Drawing.SolidBrush $ink
    $h1 = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(235, 255, 255, 255))
    $h2 = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(200, 255, 255, 255))
    $s  = $Scale
    try {
        $G.FillEllipse($w,  $X - (17 * $s), $Y - (19 * $s), 34 * $s, 38 * $s)   # 眼白
        $G.FillEllipse($p,  $X - (12 * $s), $Y - (14 * $s), 24 * $s, 30 * $s)   # 瞳孔
        $G.FillEllipse($h1, $X - (8 * $s),  $Y - (12 * $s), 12 * $s, 13 * $s)   # 大高光
        $G.FillEllipse($h2, $X + (2 * $s),  $Y + (6 * $s),  7 * $s,  7 * $s)    # 小高光
    }
    finally { $w.Dispose(); $p.Dispose(); $h1.Dispose(); $h2.Dispose() }
}

# ---------------------------------------------------------------------------
# 核心绘制：在 256x256 的逻辑坐标里画鲸鱼
# ---------------------------------------------------------------------------
function Draw-Whale {
    param([System.Drawing.Graphics]$G)

    $G.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $G.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $G.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $G.Clear([System.Drawing.Color]::Transparent)

    # --- 调色板（DeepSeek 蓝） -------------------------------------------
    $blueLight = '#8FD8FF'
    $blueMain  = '#4D9DF6'
    $blueDeep  = '#2A6ED8'
    $ink       = '#1B2A4A'
    $white     = '#FFFFFF'
    $blush     = '#FF9EB5'

    # --- 身体（圆胖水滴形：右侧圆头，向左收成尾柄） ----------------------
    $body = New-Object System.Drawing.Drawing2D.GraphicsPath
    $bodyPts = @(
        [System.Drawing.PointF]::new(56, 136),
        [System.Drawing.PointF]::new(74, 96),
        [System.Drawing.PointF]::new(112, 62),
        [System.Drawing.PointF]::new(168, 54),
        [System.Drawing.PointF]::new(212, 82),
        [System.Drawing.PointF]::new(226, 130),
        [System.Drawing.PointF]::new(206, 182),
        [System.Drawing.PointF]::new(156, 208),
        [System.Drawing.PointF]::new(102, 190),
        [System.Drawing.PointF]::new(70, 166)
    )
    $body.AddClosedCurve($bodyPts, 0.45)
    $bodyBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        [System.Drawing.RectangleF]::new(60, 54, 166, 154),
        [System.Drawing.ColorTranslator]::FromHtml($blueLight),
        [System.Drawing.ColorTranslator]::FromHtml($blueMain),
        90.0)
    $G.FillPath($bodyBrush, $body)

    # --- 尾鳍（左侧两瓣，压在身体下方先画，形成连体轮廓） ----------------
    $flukeColor = [System.Drawing.ColorTranslator]::FromHtml($blueDeep)
    foreach ($flip in @(1, -1)) {
        $pts = @(
            [System.Drawing.PointF]::new(86, 138),
            [System.Drawing.PointF]::new(52, 118 + (10 * $flip)),
            [System.Drawing.PointF]::new(22, 112 + (26 * $flip)),
            [System.Drawing.PointF]::new(44, 140 + (18 * $flip))
        )
        $tailPath = New-Object System.Drawing.Drawing2D.GraphicsPath
        $tailPath.AddClosedCurve($pts, 0.45)
        $tailBrush = New-Object System.Drawing.SolidBrush $flukeColor
        $G.FillPath($tailBrush, $tailPath)
        $tailBrush.Dispose(); $tailPath.Dispose()
    }

    # 身体轮廓（描边）
    $G.DrawPath((New-Pen $blueDeep 4), $body)

    # --- 肚皮（浅色分区，鲸鱼标志性的腹部线条） --------------------------
    $belly = New-Object System.Drawing.Drawing2D.GraphicsPath
    $bellyPts = @(
        [System.Drawing.PointF]::new(70, 158),
        [System.Drawing.PointF]::new(104, 176),
        [System.Drawing.PointF]::new(140, 190),
        [System.Drawing.PointF]::new(180, 190),
        [System.Drawing.PointF]::new(206, 168),
        [System.Drawing.PointF]::new(196, 146),
        [System.Drawing.PointF]::new(150, 140),
        [System.Drawing.PointF]::new(104, 140)
    )
    $belly.AddClosedCurve($bellyPts, 0.5)
    $bellyBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(205, 255, 255, 255))
    $G.FillPath($bellyBrush, $belly)

    # --- 胸鳍（身体前下方的小鳍） ----------------------------------------
    $fin = New-Object System.Drawing.Drawing2D.GraphicsPath
    $finPts = @(
        [System.Drawing.PointF]::new(152, 168),
        [System.Drawing.PointF]::new(186, 172),
        [System.Drawing.PointF]::new(180, 204),
        [System.Drawing.PointF]::new(154, 200)
    )
    $fin.AddClosedCurve($finPts, 0.35)
    $finBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($blueDeep))
    $G.FillPath($finBrush, $fin)

    # --- 眼睛（大眼睛 + 双高光，卡通萌感） ------------------------------
    Add-Eye -G $G -X 124 -Y 106 -Scale 1.18
    Add-Eye -G $G -X 186 -Y 106 -Scale 1.18

    # --- 腮红（放在嘴巴外上方，避免与嘴线打架） --------------------------
    $blushBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(140,
        [System.Drawing.ColorTranslator]::FromHtml($blush)))
    $G.FillEllipse($blushBrush, 96, 126, 28, 15)
    $G.FillEllipse($blushBrush, 188, 126, 28, 15)

    # --- 鲸鱼标志性的长嘴线（微笑）+ 嘴角上翘 ----------------------------
    $mouthPen = New-Pen $ink 5
    $mouthPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $mouthPen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
    $mouth = New-Object System.Drawing.Drawing2D.GraphicsPath
    $mouth.AddBezier(94, 140, 140, 156, 182, 150, 206, 124)
    $G.DrawPath($mouthPen, $mouth)

    # --- 头顶喷水孔的小水花（辨识度） -------------------------------------
    $spoutPen = New-Pen $white 6
    $spoutPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $spoutPen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
    $G.DrawLine($spoutPen, 176, 48, 172, 28)
    $G.DrawLine($spoutPen, 190, 46, 192, 26)
    $G.DrawLine($spoutPen, 204, 50, 210, 32)
    $drop = New-Object System.Drawing.SolidBrush $white
    $G.FillEllipse($drop, 164, 16, 12, 12)
    $G.FillEllipse($drop, 196, 12, 10, 10)
    $G.FillEllipse($drop, 212, 20, 9, 9)

    # --- 释放 -------------------------------------------------------------
    @($body, $bodyBrush, $belly, $bellyBrush,
      $fin, $finBrush, $blushBrush, $mouthPen, $mouth, $spoutPen, $drop) |
        ForEach-Object { $_.Dispose() }
}

function New-WhaleBitmap {
    param([int]$Size)
    $bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $scale = [single]($Size / $Master)
    $g.ScaleTransform($scale, $scale)
    Draw-Whale -G $g
    $g.Dispose()
    return $bmp
}

# ---------------------------------------------------------------------------
# 组装 ICO（每个尺寸都写 PNG 数据，Windows Vista+ 原生支持）
# ---------------------------------------------------------------------------
function New-WhaleIcon {
    param([string]$Path, [int[]]$SizeList)

    $SizeList = $SizeList | Sort-Object -Unique
    $images = @()
    foreach ($s in $SizeList) {
        $bmp = New-WhaleBitmap -Size $s
        $ms = New-Object System.IO.MemoryStream
        $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $images += , @{ Size = $s; Bytes = $ms.ToArray() }
        $ms.Dispose(); $bmp.Dispose()
    }

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    $fs = [System.IO.File]::Create($Path)
    $bw = New-Object System.IO.BinaryWriter($fs)
    try {
        # ICONDIR
        $bw.Write([uint16]0)                 # reserved
        $bw.Write([uint16]1)                 # type = icon
        $bw.Write([uint16]$images.Count)     # image count

        # ICONDIRENTRY * n
        $offset = 6 + (16 * $images.Count)
        foreach ($img in $images) {
            $dim = if ($img.Size -ge 256) { 0 } else { $img.Size }
            $bw.Write([byte]$dim)            # width
            $bw.Write([byte]$dim)            # height
            $bw.Write([byte]0)               # color count
            $bw.Write([byte]0)               # reserved
            $bw.Write([uint16]1)             # color planes
            $bw.Write([uint16]32)            # bits per pixel
            $bw.Write([uint32]$img.Bytes.Length)
            $bw.Write([uint32]$offset)
            $offset += $img.Bytes.Length
        }

        # 图像数据
        foreach ($img in $images) { $bw.Write($img.Bytes) }
    }
    finally {
        $bw.Flush(); $bw.Dispose(); $fs.Dispose()
    }

    return $Path
}

if ($MyInvocation.InvocationName -ne '.') {
    $result = New-WhaleIcon -Path $OutFile -SizeList $Sizes
    Write-Host "已生成鲸鱼图标: $result" -ForegroundColor Cyan
}
