param(
  [string]$ApprovedMark = '.\scripts\card-assets\sources\app-icon-f-four-suits-mark.png',
  [string]$AppScopeMediaDirectory = '.\AppScope\resources\base\media',
  [string]$EntryMediaDirectory = '.\entry\src\main\resources\base\media'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$iconSize = 1024
$startIconSize = 144
$field = [System.Drawing.ColorTranslator]::FromHtml('#0B5B36')

function New-Canvas([int]$Size) {
  return [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

function Set-Quality([System.Drawing.Graphics]$Graphics) {
  $Graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $Graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $Graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
}

function Save-Png([System.Drawing.Bitmap]$Bitmap, [string]$Path) {
  $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
}

$approved = [System.Drawing.Bitmap]::FromFile((Resolve-Path $ApprovedMark))
try {
  $background = New-Canvas $iconSize
  $backgroundGraphics = [System.Drawing.Graphics]::FromImage($background)
  try { $backgroundGraphics.Clear($field) } finally { $backgroundGraphics.Dispose() }

  $foreground = New-Canvas $iconSize
  $foregroundGraphics = [System.Drawing.Graphics]::FromImage($foreground)
  try {
    Set-Quality $foregroundGraphics
    $foregroundGraphics.Clear([System.Drawing.Color]::Transparent)
    $foregroundGraphics.DrawImage($approved, 0, 0, $iconSize, $iconSize)
  } finally { $foregroundGraphics.Dispose() }

  foreach ($directory in @($AppScopeMediaDirectory, $EntryMediaDirectory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    Save-Png $background (Join-Path $directory 'background.png')
    Save-Png $foreground (Join-Path $directory 'foreground.png')
  }

  # The launch window does not apply the launcher mask, so give its flattened
  # icon the same rounded silhouette users see on the home screen.
  $startIcon = New-Canvas $startIconSize
  $startGraphics = [System.Drawing.Graphics]::FromImage($startIcon)
  $clipPath = [System.Drawing.Drawing2D.GraphicsPath]::new()
  try {
    Set-Quality $startGraphics
    $radius = 32.0
    $diameter = $radius * 2
    $clipPath.AddArc(0, 0, $diameter, $diameter, 180, 90)
    $clipPath.AddArc($startIconSize - $diameter, 0, $diameter, $diameter, 270, 90)
    $clipPath.AddArc($startIconSize - $diameter, $startIconSize - $diameter, $diameter, $diameter, 0, 90)
    $clipPath.AddArc(0, $startIconSize - $diameter, $diameter, $diameter, 90, 90)
    $clipPath.CloseFigure()
    $startGraphics.SetClip($clipPath)
    $startGraphics.Clear($field)
    $startGraphics.DrawImage($approved, 0, 0, $startIconSize, $startIconSize)
  } finally {
    $clipPath.Dispose()
    $startGraphics.Dispose()
  }
  Save-Png $startIcon (Join-Path $EntryMediaDirectory 'startIcon.png')

  $startIcon.Dispose()
  $foreground.Dispose()
  $background.Dispose()
} finally {
  $approved.Dispose()
}

Write-Host 'Installed approved Four Suits Mark as the launcher, ability, and start-window icon.'
