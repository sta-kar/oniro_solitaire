param(
  [string]$MediaDirectory = '.\entry\src\main\resources\base\media',
  [string]$OutputDirectory = '.\entry\src\main\resources\base\media'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Generate portable runtime bitmaps from the reviewed, renderer-compatible SVGs.
# Six pixels per reference unit preserves the exact 2:3 card geometry.
$width = 270
$height = 405
$renderer = (Get-Command rsvg-convert.exe -ErrorAction SilentlyContinue)
if ($null -eq $renderer) {
  $renderer = Get-Command rsvg-convert -ErrorAction Stop
}
$sourcePath = (Resolve-Path -LiteralPath $MediaDirectory).Path
$cards = @(Get-ChildItem -LiteralPath $sourcePath -Filter 'playing_card*.svg' -File | Sort-Object Name)
if ($cards.Count -ne 109) {
  throw "Expected 104 faces and five backs, found $($cards.Count) SVG files."
}

# Validate every input before overwriting any previously generated bitmap.
foreach ($card in $cards) {
  [xml]$svg = Get-Content -LiteralPath $card.FullName -Raw
  if ($svg.DocumentElement.GetAttribute('viewBox') -ne '0 0 45 67.5') {
    throw "Unexpected card geometry: $($card.Name)"
  }
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$outputPath = (Resolve-Path -LiteralPath $OutputDirectory).Path
foreach ($card in $cards) {
  $destination = Join-Path $outputPath ($card.BaseName + '_raster.png')
  & $renderer.Source --width $width --height $height --output $destination $card.FullName
  if ($LASTEXITCODE -ne 0) {
    throw "Rasterization failed for $($card.Name)"
  }
}

Write-Output "Rasterized $($cards.Count) card resources at $width x $height into $outputPath."
