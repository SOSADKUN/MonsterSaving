# Package the supplied artwork without redrawing it.
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path $PSScriptRoot -Parent
$sourcePath = Join-Path $projectRoot 'assets\videos\icon.png'
$source = [System.Drawing.Image]::FromFile($sourcePath)
function Write-LauncherIcon([string]$target, [int]$edge, [bool]$transparent = $false, [double]$padding = 0.04) {
  $format = if ($transparent) { [System.Drawing.Imaging.PixelFormat]::Format32bppArgb } else { [System.Drawing.Imaging.PixelFormat]::Format24bppRgb }
  $bitmap = New-Object System.Drawing.Bitmap($edge, $edge, $format)
  $g = [System.Drawing.Graphics]::FromImage($bitmap)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  if ($transparent) { $g.Clear([System.Drawing.Color]::Transparent) } else { $g.Clear([System.Drawing.ColorTranslator]::FromHtml('#F0F7E6')) }
  $inset = [single]($edge * $padding)
  $size = [single]($edge - 2 * $inset)
  $g.DrawImage($source, [System.Drawing.RectangleF]::new($inset, $inset, $size, $size))
  $bitmap.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bitmap.Dispose()
}
try {
  $icons = Get-ChildItem -Path "$projectRoot\android\app\src\main\res\mipmap-*\ic_launcher.png","$projectRoot\ios\Runner\Assets.xcassets\AppIcon.appiconset\*.png","$projectRoot\web\icons\*.png","$projectRoot\web\favicon.png"
  foreach ($icon in $icons) {
    $existing = [System.Drawing.Image]::FromFile($icon.FullName)
    $edge = $existing.Width
    $existing.Dispose()
    Write-LauncherIcon $icon.FullName $edge
  }
  $adaptiveDirectory = Join-Path $projectRoot 'android\app\src\main\res\drawable-xxxhdpi'
  New-Item -ItemType Directory -Force $adaptiveDirectory | Out-Null
  Write-LauncherIcon (Join-Path $adaptiveDirectory 'ic_launcher_foreground.png') 432 $true 0.18
} finally { $source.Dispose() }
