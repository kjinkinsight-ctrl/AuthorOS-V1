Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$iconsDir = Join-Path $root "src-tauri\icons"
$brandingDir = Join-Path $root "src-tauri\branding"

New-Item -ItemType Directory -Force -Path $iconsDir | Out-Null
New-Item -ItemType Directory -Force -Path $brandingDir | Out-Null

$background = [System.Drawing.Color]::FromArgb(27, 37, 57)
$panel = [System.Drawing.Color]::FromArgb(198, 145, 85)
$text = [System.Drawing.Color]::FromArgb(249, 244, 236)
$muted = [System.Drawing.Color]::FromArgb(225, 212, 194)

function New-Canvas($width, $height) {
    $bitmap = New-Object System.Drawing.Bitmap($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.Clear($background)
    return @{ Bitmap = $bitmap; Graphics = $graphics }
}

function Save-Png($canvas, $path) {
    $canvas.Bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $canvas.Graphics.Dispose()
    $canvas.Bitmap.Dispose()
}

function New-AppIcon($size, $path) {
    $canvas = New-Canvas $size $size
    $g = $canvas.Graphics
    $bitmap = $canvas.Bitmap

    $outer = [Math]::Round($size * 0.12)
    $panelRect = New-Object System.Drawing.RectangleF($outer, $outer, $size - ($outer * 2), $size - ($outer * 2))
    $radius = [Math]::Round($size * 0.16)

    $pathShape = New-Object System.Drawing.Drawing2D.GraphicsPath
    $diameter = $radius * 2
    $pathShape.AddArc($panelRect.X, $panelRect.Y, $diameter, $diameter, 180, 90)
    $pathShape.AddArc($panelRect.Right - $diameter, $panelRect.Y, $diameter, $diameter, 270, 90)
    $pathShape.AddArc($panelRect.Right - $diameter, $panelRect.Bottom - $diameter, $diameter, $diameter, 0, 90)
    $pathShape.AddArc($panelRect.X, $panelRect.Bottom - $diameter, $diameter, $diameter, 90, 90)
    $pathShape.CloseFigure()

    $g.FillPath((New-Object System.Drawing.SolidBrush($panel)), $pathShape)

    $fontSize = [Math]::Round($size * 0.42)
    $font = New-Object System.Drawing.Font("Georgia", $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $brush = New-Object System.Drawing.SolidBrush($text)
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center

    $textRect = New-Object System.Drawing.RectangleF(0, [Math]::Round($size * 0.02), $size, $size)
    $g.DrawString("A", $font, $brush, $textRect, $format)

    $font.Dispose()
    $brush.Dispose()
    $format.Dispose()
    $pathShape.Dispose()

    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bitmap.Dispose()
}

function New-IcoFromPng($pngPath, $icoPath) {
    $pngBytes = [System.IO.File]::ReadAllBytes($pngPath)
    $stream = [System.IO.File]::Open($icoPath, [System.IO.FileMode]::Create)
    $writer = New-Object System.IO.BinaryWriter($stream)

    $writer.Write([byte[]](0,0))
    $writer.Write([byte[]](1,0))
    $writer.Write([byte[]](1,0))
    $writer.Write([byte]0)
    $writer.Write([byte]0)
    $writer.Write([byte]0)
    $writer.Write([byte]0)
    $writer.Write([byte[]](1,0))
    $writer.Write([byte[]](32,0))
    $writer.Write([BitConverter]::GetBytes([int]$pngBytes.Length))
    $writer.Write([BitConverter]::GetBytes([int]22))
    $writer.Write($pngBytes)
    $writer.Flush()
    $writer.Dispose()
    $stream.Dispose()
}

function New-Banner($width, $height, $path, $title, $subtitle) {
    $canvas = New-Canvas $width $height
    $g = $canvas.Graphics

    $g.FillRectangle((New-Object System.Drawing.SolidBrush($panel)), 0, 0, [Math]::Round($width * 0.26), $height)

    $titleFontSize = [Math]::Max(16, [Math]::Round($height * 0.42))
    $subtitleFontSize = [Math]::Max(8, [Math]::Round($height * 0.2))
    $titleFont = New-Object System.Drawing.Font("Georgia", $titleFontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $subtitleFont = New-Object System.Drawing.Font("Segoe UI", $subtitleFontSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $titleBrush = New-Object System.Drawing.SolidBrush($text)
    $subtitleBrush = New-Object System.Drawing.SolidBrush($muted)

    $g.DrawString($title, $titleFont, $titleBrush, 20, [Math]::Round($height * 0.14))
    $g.DrawString($subtitle, $subtitleFont, $subtitleBrush, [Math]::Round($width * 0.30), [Math]::Round($height * 0.38))

    $titleFont.Dispose()
    $subtitleFont.Dispose()
    $titleBrush.Dispose()
    $subtitleBrush.Dispose()

    $canvas.Bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Bmp)
    $canvas.Graphics.Dispose()
    $canvas.Bitmap.Dispose()
}

function New-Sidebar($width, $height, $path) {
    $canvas = New-Canvas $width $height
    $g = $canvas.Graphics

    $g.FillRectangle((New-Object System.Drawing.SolidBrush($panel)), 0, 0, $width, [Math]::Round($height * 0.32))

    $markFont = New-Object System.Drawing.Font("Georgia", 68, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $titleFont = New-Object System.Drawing.Font("Georgia", 18, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $copyFont = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $lightBrush = New-Object System.Drawing.SolidBrush($text)
    $mutedBrush = New-Object System.Drawing.SolidBrush($muted)

    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center

    $g.DrawString("A", $markFont, $lightBrush, (New-Object System.Drawing.RectangleF(0, 16, $width, 90)), $format)
    $g.DrawString("Author Studio", $titleFont, $lightBrush, 18, [Math]::Round($height * 0.40))
    $g.DrawString("Desktop writing workspace for projects, chapters, story notes, and exports.", $copyFont, $mutedBrush, (New-Object System.Drawing.RectangleF(18, [Math]::Round($height * 0.48), $width - 36, 120)))

    $markFont.Dispose()
    $titleFont.Dispose()
    $copyFont.Dispose()
    $lightBrush.Dispose()
    $mutedBrush.Dispose()
    $format.Dispose()

    $canvas.Bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Bmp)
    $canvas.Graphics.Dispose()
    $canvas.Bitmap.Dispose()
}

New-AppIcon 32 (Join-Path $iconsDir "32x32.png")
New-AppIcon 128 (Join-Path $iconsDir "128x128.png")
New-AppIcon 256 (Join-Path $iconsDir "128x128@2x.png")
New-IcoFromPng (Join-Path $iconsDir "128x128@2x.png") (Join-Path $iconsDir "icon.ico")

New-Banner 150 57 (Join-Path $brandingDir "nsis-header.bmp") "Author Studio" "Write offline. Export safely."
New-Sidebar 164 314 (Join-Path $brandingDir "nsis-sidebar.bmp")
New-Banner 493 58 (Join-Path $brandingDir "wix-banner.bmp") "Author Studio" "Offline-first desktop writing workspace"
New-Sidebar 493 312 (Join-Path $brandingDir "wix-dialog.bmp")

Write-Host "Generated Tauri icons and branding assets."
