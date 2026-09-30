param(
  [Parameter(Mandatory = $true)]
  [string]$CardDirectory,

  [Parameter(Mandatory = $true)]
  [string]$LogoSvgPath,

  [string]$PackagedMediaDirectory = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$invariant = [System.Globalization.CultureInfo]::InvariantCulture
$sourceCardHeight = 68.0
$targetCardWidth = 45.0
$targetCardHeight = $targetCardWidth * 3.0 / 2.0
$cardVerticalScale = $targetCardHeight / $sourceCardHeight
$legacySpadePath = 'M0-11C-2-7-9-3-9 3C-9 8-3 10 0 6C0 9-2 12-4 13H4C2 12 0 9 0 6C3 10 9 8 9 3C9-3 2-7 0-11Z'
$rendererSafeSpadePath = 'M0-11C-2-7-9-3-9 3C-9 8-3 10-0.5 6C-0.4 9-2 12-4 13H4C2 12 0.4 9 0.5 6C3 10 9 8 9 3C9-3 2-7 0-11Z'
$unbridgedClubPath = 'M0-10A5 5 0 1 1 0 0A5 5 0 1 1 0-10Z M-5-3A5 5 0 1 1-5 7A5 5 0 1 1-5-3Z M5-3A5 5 0 1 1 5 7A5 5 0 1 1 5-3Z M-2 4C-2 8-3 10-5 12H5C3 10 2 8 2 4Z'
$solidClubPath = 'M0-10A5 5 0 1 1 0 0A5 5 0 1 1 0-10Z M-5-3A5 5 0 1 1-5 7A5 5 0 1 1-5-3Z M5-3A5 5 0 1 1 5 7A5 5 0 1 1 5-3Z M-2.5-3.5H2.5V4H2C2 8 3 10 5 12H-5C-3 10-2 8-2 4H-2.5Z'

function Format-Number([double]$Value) {
  return $Value.ToString('0.###', $invariant)
}

function Convert-ToTwoThreeCardSvg([string]$Svg) {
  if ($Svg.Contains('data-card-aspect="2:3"')) { return $Svg }

  $sourceRoot = '<svg xmlns="http://www.w3.org/2000/svg" width="45" height="68" viewBox="0 0 45 68" preserveAspectRatio="xMidYMid meet">'
  $targetRoot = '<svg xmlns="http://www.w3.org/2000/svg" width="45" height="67.5" viewBox="0 0 45 67.5" preserveAspectRatio="xMidYMid meet" data-card-aspect="2:3">'
  if (-not $Svg.Contains($sourceRoot)) { throw 'Card SVG does not use the expected 45-by-68 source viewport.' }

  $result = $Svg.Replace($sourceRoot, $targetRoot)
  $scale = $cardVerticalScale.ToString('0.################', $invariant)
  $result = $result.Replace('</title>', "</title>`n  <g transform=`"scale(1 $scale)`" data-source-viewBox=`"0 0 45 68`">")
  $closingIndex = $result.LastIndexOf('</svg>')
  if ($closingIndex -lt 0) { throw 'Card SVG is missing its closing element.' }
  return $result.Substring(0, $closingIndex) + "  </g>`n" + $result.Substring($closingIndex)
}

function Convert-AceViewportForArkUi([string]$Svg) {
  $nestedRoot = '<svg x="9" y="20.5" width="27" height="27" viewBox="0 0 153 153" preserveAspectRatio="xMidYMid meet" overflow="hidden">'
  if (-not $Svg.Contains($nestedRoot)) { return $Svg }

  $groupRoot = '<g transform="translate(9 20.5) scale(0.1764705882352941)">'
  $result = $Svg.Replace($nestedRoot, $groupRoot)
  $groupIndex = $result.IndexOf($groupRoot)
  $nestedClosingIndex = $result.IndexOf('  </svg>', $groupIndex)
  if ($nestedClosingIndex -lt 0) { throw 'Ace SVG is missing its nested viewport closing element.' }
  return $result.Substring(0, $nestedClosingIndex) + '  </g>' + $result.Substring($nestedClosingIndex + 8)
}

function Convert-ToRendererSafeSpades([string]$Svg) {
  # The legacy spade contour revisits (0, 6) where its head meets its stem.
  # OpenHarmony can rasterize that self-touch as a white notch after a 180°
  # rotation. A one-unit-wide neck preserves the silhouette and makes the
  # contour simple, so upright and inverted pips share the same solid fill.
  return $Svg.Replace($legacySpadePath, $rendererSafeSpadePath)
}

function Convert-ToSolidClubs([string]$Svg) {
  # Render every club as one compound path. This preserves the existing
  # three-lobe silhouette while preventing white seams between primitives.
  $legacyClubPattern = '<g fill="([^"]+)" transform="([^"]+)"><circle cx="0" cy="-5" r="5"/><circle cx="-5" cy="2" r="5"/><circle cx="5" cy="2" r="5"/><path d="M-2 4C-2 8-3 10-5 12H5C3 10 2 8 2 4Z"/>(?:<rect x="-2\.5" y="-3\.5" width="5" height="7\.5"/>)?</g>'
  $result = $Svg.Replace($unbridgedClubPath, $solidClubPath)
  return [regex]::Replace($result, $legacyClubPattern, {
    param($match)
    return '<path d="' + $solidClubPath + '" fill="' + $match.Groups[1].Value +
      '" transform="' + $match.Groups[2].Value + '"/>'
  })
}

function Replace-TransformY([string]$Svg, [double]$X, [double]$OldY, [double]$NewY) {
  $oldTransform = 'translate\(' + [regex]::Escape((Format-Number $X)) + ' ' +
    [regex]::Escape((Format-Number $OldY)) + '\)'
  $newTransform = 'translate(' + (Format-Number $X) + ' ' + (Format-Number $NewY) + ')'
  return [regex]::Replace($Svg, $oldTransform, $newTransform)
}

function Get-InnerSvg([string]$Svg) {
  $match = [regex]::Match($Svg, '<svg[^>]*>([\s\S]*)</svg>')
  if (-not $match.Success) { throw 'Could not extract SVG contents.' }
  return $match.Groups[1].Value
}

[xml]$logoDocument = Get-Content -Raw -LiteralPath $LogoSvgPath
$logoPaths = @($logoDocument.SelectNodes('/*[local-name()="svg"]/*[local-name()="path"]')) |
  ForEach-Object { $_.OuterXml }
$logoMarkup = @"
<g transform="translate(9.9 21.715) scale(0.63)">
    $($logoPaths -join "`n    ")
  </g>
"@

$aceLogoPattern = '<g transform="translate\(22\.5 34\) scale\(0\.72\)">[\s\S]*?</g>'
foreach ($aceFile in (Get-ChildItem -LiteralPath $CardDirectory -Filter 'ace_of_*.svg')) {
  $svg = Get-Content -Raw -LiteralPath $aceFile.FullName
  $svg = [regex]::Replace($svg, $aceLogoPattern, $logoMarkup)
  [System.IO.File]::WriteAllText($aceFile.FullName, $svg, $utf8NoBom)
}

foreach ($rank in 2..10) {
  foreach ($cardFile in (Get-ChildItem -LiteralPath $CardDirectory -Filter ($rank.ToString() + '_of_*.svg'))) {
    $svg = Get-Content -Raw -LiteralPath $cardFile.FullName
    $svg = $svg.Replace('scale(0.34)', 'scale(0.408)')

    if ($rank -eq 9) {
      foreach ($x in @(16.3, 28.7)) {
        $svg = Replace-TransformY $svg $x 13 12.5
        $svg = Replace-TransformY $svg $x 27 25.5
        $svg = Replace-TransformY $svg $x 41 42.5
        $svg = Replace-TransformY $svg $x 55 55.5
      }
    }

    if ($rank -eq 10) {
      $svg = Replace-TransformY $svg 22.5 20 19
      $svg = Replace-TransformY $svg 22.5 48 49
      foreach ($x in @(16.3, 28.7)) {
        $svg = Replace-TransformY $svg $x 27 26
        $svg = Replace-TransformY $svg $x 41 42
      }
    }

    [System.IO.File]::WriteAllText($cardFile.FullName, $svg, $utf8NoBom)
  }
}

foreach ($cardFile in (Get-ChildItem -LiteralPath $CardDirectory -Filter '*.svg' |
    Where-Object { $_.Name -ne 'all-cards.svg' })) {
  $svg = Get-Content -Raw -LiteralPath $cardFile.FullName
  $svg = Convert-ToRendererSafeSpades $svg
  $svg = Convert-ToSolidClubs $svg
  $svg = Convert-ToTwoThreeCardSvg $svg
  [System.IO.File]::WriteAllText($cardFile.FullName, $svg, $utf8NoBom)
}

$suits = @('clubs', 'diamonds', 'hearts', 'spades')
$rankFiles = @('ace', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'jack', 'queen', 'king')
$sheetWidth = 1600
$sheetHeight = 970
$scale = 2.4
$cardWidth = 45 * $scale
$cardHeight = $targetCardHeight * $scale
$left = 56
$top = 60
$columnGap = 6
$rowGap = 9
$sheet = [System.Collections.Generic.List[string]]::new()
$sheet.Add('<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="970" viewBox="0 0 1600 970">')
$sheet.Add('<title>Complete Oniro solitaire card set</title>')
$sheet.Add('<rect width="1600" height="970" fill="#0B6E3F"/>')
$sheet.Add('<text x="56" y="36" fill="#FFFFFF" font-family="Arial, sans-serif" font-size="22" font-weight="700">Oniro Solitaire — traditional card set</text>')

for ($row = 0; $row -lt $suits.Count; $row++) {
  for ($column = 0; $column -lt $rankFiles.Count; $column++) {
    $fileName = '{0}_of_{1}.svg' -f $rankFiles[$column], $suits[$row]
    $svg = Get-Content -Raw -LiteralPath (Join-Path $CardDirectory $fileName)
    $x = $left + ($column * ($cardWidth + $columnGap))
    $y = $top + ($row * ($cardHeight + $rowGap))
    $sheet.Add(('<g transform="translate({0} {1}) scale({2})">{3}</g>' -f
      (Format-Number $x), (Format-Number $y), (Format-Number $scale), (Get-InnerSvg $svg)))
  }
}

$backSvg = Get-Content -Raw -LiteralPath (Join-Path $CardDirectory 'card_back.svg')
$backX = $left + (6 * ($cardWidth + $columnGap))
$backY = $top + (4 * ($cardHeight + $rowGap))
$sheet.Add(('<g transform="translate({0} {1}) scale({2})">{3}</g>' -f
  (Format-Number $backX), (Format-Number $backY), (Format-Number $scale), (Get-InnerSvg $backSvg)))
$sheet.Add(('<text x="{0}" y="{1}" fill="#FFFFFF" font-family="Arial, sans-serif" font-size="17" text-anchor="middle">card back</text>' -f
  (Format-Number ($backX + ($cardWidth / 2))), (Format-Number ($backY + $cardHeight + 24))))
$sheet.Add('</svg>')
[System.IO.File]::WriteAllText((Join-Path $CardDirectory 'all-cards.svg'), ($sheet -join "`n"), $utf8NoBom)

if (-not [string]::IsNullOrWhiteSpace($PackagedMediaDirectory)) {
  [System.IO.Directory]::CreateDirectory($PackagedMediaDirectory) | Out-Null
  foreach ($cardFile in (Get-ChildItem -LiteralPath $CardDirectory -Filter '*.svg' |
      Where-Object { $_.Name -ne 'all-cards.svg' })) {
    $destination = Join-Path $PackagedMediaDirectory ('playing_card_' + $cardFile.Name)
    if ($cardFile.Name -like 'ace_of_*.svg') {
      $svg = Get-Content -Raw -LiteralPath $cardFile.FullName
      $svg = Convert-AceViewportForArkUi $svg
      [System.IO.File]::WriteAllText($destination, $svg, $utf8NoBom)
    } else {
      [System.IO.File]::Copy($cardFile.FullName, $destination, $true)
    }
  }
}

Write-Output 'Polished card artwork, normalized every card to 2:3, applied renderer-safe spades, and refreshed packaged resources when requested.'
