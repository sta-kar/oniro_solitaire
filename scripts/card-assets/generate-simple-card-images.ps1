param(
  [string]$OutputDirectory = '.\card-images-simple',
  [string]$PackagedMediaDirectory = '.\entry\src\main\resources\base\media'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$invariant = [System.Globalization.CultureInfo]::InvariantCulture
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Format-Number([double]$Value) {
  return $Value.ToString('0.###', $invariant)
}

function Convert-GraphicsPathToSvg([System.Drawing.Drawing2D.GraphicsPath]$Path) {
  $points = $Path.PathPoints
  $types = $Path.PathTypes
  $parts = [System.Collections.Generic.List[string]]::new()
  $index = 0
  while ($index -lt $points.Length) {
    $kind = $types[$index] -band 7
    $closed = ($types[$index] -band 128) -ne 0
    if ($kind -eq 0) {
      $parts.Add(('M{0} {1}' -f (Format-Number $points[$index].X), (Format-Number $points[$index].Y)))
    } elseif ($kind -eq 1) {
      $parts.Add(('L{0} {1}' -f (Format-Number $points[$index].X), (Format-Number $points[$index].Y)))
    } elseif ($kind -eq 3) {
      $c1 = $points[$index]
      $c2 = $points[$index + 1]
      $end = $points[$index + 2]
      $parts.Add(('C{0} {1} {2} {3} {4} {5}' -f
        (Format-Number $c1.X), (Format-Number $c1.Y),
        (Format-Number $c2.X), (Format-Number $c2.Y),
        (Format-Number $end.X), (Format-Number $end.Y)))
      $closed = ($types[$index + 2] -band 128) -ne 0
      $index += 2
    }
    if ($closed) { $parts.Add('Z') }
    $index++
  }
  return $parts -join ' '
}

function Get-RankArtwork([string]$Label, [double]$EmSize, [double]$Left, [double]$Top) {
  $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
  $path.AddString(
    $Label,
    [System.Drawing.FontFamily]::GenericSansSerif,
    [int][System.Drawing.FontStyle]::Bold,
    [single]$EmSize,
    [System.Drawing.PointF]::new(0, 0),
    [System.Drawing.StringFormat]::GenericTypographic
  )
  $bounds = $path.GetBounds()
  $matrix = [System.Drawing.Drawing2D.Matrix]::new()
  $matrix.Translate([single]($Left - $bounds.X), [single]($Top - $bounds.Y))
  $path.Transform($matrix)
  $result = [pscustomobject]@{
    Path = Convert-GraphicsPathToSvg $path
    Left = $Left
    Top = $Top
    Right = $Left + $bounds.Width
    Height = $bounds.Height
  }
  $matrix.Dispose()
  $path.Dispose()
  return $result
}

$suits = @(
  @{
    Name = 'clubs'
    Ink = '#171717'
    Path = 'M0-10A5 5 0 1 1 0 0A5 5 0 1 1 0-10Z M-5-3A5 5 0 1 1-5 7A5 5 0 1 1-5-3Z M5-3A5 5 0 1 1 5 7A5 5 0 1 1 5-3Z M-2.5-3.5H2.5V4H2C2 8 3 10 5 12H-5C-3 10-2 8-2 4H-2.5Z'
    MinX = -10.0
    MinY = -10.0
    MaxY = 12.0
  },
  @{
    Name = 'diamonds'
    Ink = '#C62828'
    Path = 'M0-10L8 0L0 10L-8 0Z'
    MinX = -8.0
    MinY = -10.0
    MaxY = 10.0
  },
  @{
    Name = 'hearts'
    Ink = '#C62828'
    Path = 'M0 9C-2 6-9 1-9-4C-9-9-3-11 0-6C3-11 9-9 9-4C9 1 2 6 0 9Z'
    MinX = -9.0
    MinY = -11.0
    MaxY = 9.0
  },
  @{
    Name = 'spades'
    Ink = '#171717'
    Path = 'M0-11C-2-7-9-3-9 3C-9 8-3 10-.5 6C-.4 9-2 12-4 13H4C2 12 .4 9 .5 6C3 10 9 8 9 3C9-3 2-7 0-11Z'
    MinX = -9.0
    MinY = -11.0
    MaxY = 13.0
  }
)
$ranks = @(
  @{ Value = 1; Label = 'A'; File = 'ace' },
  @{ Value = 2; Label = '2'; File = '2' },
  @{ Value = 3; Label = '3'; File = '3' },
  @{ Value = 4; Label = '4'; File = '4' },
  @{ Value = 5; Label = '5'; File = '5' },
  @{ Value = 6; Label = '6'; File = '6' },
  @{ Value = 7; Label = '7'; File = '7' },
  @{ Value = 8; Label = '8'; File = '8' },
  @{ Value = 9; Label = '9'; File = '9' },
  @{ Value = 10; Label = '10'; File = '10' },
  @{ Value = 11; Label = 'J'; File = 'jack' },
  @{ Value = 12; Label = 'Q'; File = 'queen' },
  @{ Value = 13; Label = 'K'; File = 'king' }
)

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $PackagedMediaDirectory | Out-Null

# Approved Clean Corner geometry in the card's 45-by-67.5 coordinate system.
# The complete index fits inside both the 12.6-unit draw-three reveal and the
# 24-unit face-up tableau reveal. Its suit is deliberately more prominent than
# its rank; the body repeats the rank as a quiet distance-reading aid.
$cornerCenterX = 6.5
$cornerRankTop = 2.4
$cornerDefaultRankSize = 12.0
$cornerTenRankSize = 8.5
$cornerSuitHeight = 9.4
$cornerSuitCenterY = 17.1
$bodyDefaultRankSize = 32.0
$bodyTenRankSize = 23.0
$bodyRankCenterX = 22.5
$bodyRankCenterY = 44.0
$bodyOpacity = 0.25

foreach ($suit in $suits) {
  foreach ($rank in $ranks) {
    $cornerRankSize = if ($rank.Label -eq '10') { $cornerTenRankSize } else { $cornerDefaultRankSize }
    $cornerRankArtwork = Get-RankArtwork $rank.Label ([double]$cornerRankSize) 0.0 0.0
    $cornerRankWidth = $cornerRankArtwork.Right - $cornerRankArtwork.Left
    $cornerRankX = $cornerCenterX - ($cornerRankWidth / 2)
    $cornerRankTransform = 'translate({0} {1})' -f
      (Format-Number $cornerRankX), (Format-Number $cornerRankTop)

    $cornerSuitScale = $cornerSuitHeight / ($suit.MaxY - $suit.MinY)
    $cornerSuitY = $cornerSuitCenterY - ((($suit.MinY + $suit.MaxY) / 2) * $cornerSuitScale)
    $cornerSuitTransform = 'translate({0} {1}) scale({2})' -f
      (Format-Number $cornerCenterX), (Format-Number $cornerSuitY), (Format-Number $cornerSuitScale)

    $bodyRankSize = if ($rank.Label -eq '10') { $bodyTenRankSize } else { $bodyDefaultRankSize }
    $bodyRankArtwork = Get-RankArtwork $rank.Label $bodyRankSize 0.0 0.0
    $bodyRankWidth = $bodyRankArtwork.Right - $bodyRankArtwork.Left
    $bodyRankX = $bodyRankCenterX - ($bodyRankWidth / 2)
    $bodyRankY = $bodyRankCenterY - ($bodyRankArtwork.Height / 2)
    $bodyRankTransform = 'translate({0} {1})' -f
      (Format-Number $bodyRankX), (Format-Number $bodyRankY)

    $fileName = $rank.File + '_of_' + $suit.Name + '.svg'
    $title = 'Clean Corner ' + $rank.Label + ' of ' + $suit.Name
    $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="45" height="67.5" viewBox="0 0 45 67.5" data-card-aspect="2:3">
  <title>$title</title>
  <rect x="0.5" y="0.5" width="44" height="66.5" rx="6.5" fill="#FFFDF8" stroke="#C9C7C2"/>
  <path d="$($cornerRankArtwork.Path)" fill="$($suit.Ink)" transform="$cornerRankTransform"/>
  <path d="$($suit.Path)" fill="$($suit.Ink)" transform="$cornerSuitTransform"/>
  <path d="$($bodyRankArtwork.Path)" fill="$($suit.Ink)" opacity="$(Format-Number $bodyOpacity)" transform="$bodyRankTransform"/>
  <rect x="0.5" y="0.5" width="44" height="66.5" rx="6.5" fill="none" stroke="#C9C7C2"/>
</svg>
"@
    $sourcePath = Join-Path $OutputDirectory $fileName
    $packagedPath = Join-Path $PackagedMediaDirectory ('playing_card_simple_' + $fileName)
    [System.IO.File]::WriteAllText($sourcePath, $svg, $utf8NoBom)
    [System.IO.File]::WriteAllText($packagedPath, $svg, $utf8NoBom)
  }
}

Write-Host "Generated 52 approved Clean Corner card-front SVGs in $OutputDirectory and packaged copies in $PackagedMediaDirectory."
