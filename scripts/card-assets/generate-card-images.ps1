param(
  [Parameter(Mandatory = $true)]
  [string]$OutputDirectory,

  [string]$SourceCardDirectory = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$invariant = [System.Globalization.CultureInfo]::InvariantCulture
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$sourceCardHeight = 68.0
$targetCardWidth = 45.0
$targetCardHeight = $targetCardWidth * 3.0 / 2.0
$cardVerticalScale = $targetCardHeight / $sourceCardHeight

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

function Get-RankPath([string]$Label, [double]$EmSize, [double]$CenterX, [double]$Top) {
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
  $matrix.Translate(
    [single]($CenterX - ($bounds.X + ($bounds.Width / 2))),
    [single]($Top - $bounds.Y)
  )
  $path.Transform($matrix)
  $result = Convert-GraphicsPathToSvg $path
  $matrix.Dispose()
  $path.Dispose()
  return $result
}

function Get-SuitMarkup(
  [string]$Suit,
  [string]$Color,
  [double]$CenterX,
  [double]$CenterY,
  [double]$Scale,
  [bool]$Inverted = $false
) {
  $rotation = if ($Inverted) { ' rotate(180)' } else { '' }
  $transform = 'translate({0} {1}){2} scale({3})' -f
    (Format-Number $CenterX), (Format-Number $CenterY), $rotation, (Format-Number $Scale)
  switch ($Suit) {
    'hearts' {
      return '<path d="M0 9C-2 6-9 1-9-4C-9-9-3-11 0-6C3-11 9-9 9-4C9 1 2 6 0 9Z" fill="' + $Color + '" transform="' + $transform + '"/>'
    }
    'diamonds' {
      return '<path d="M0-10L8 0L0 10L-8 0Z" fill="' + $Color + '" transform="' + $transform + '"/>'
    }
    'spades' {
      # Keep a narrow neck between the head and stem instead of revisiting the
      # same point. OpenHarmony's SVG rasterizer can turn that self-touch into
      # a white notch when the path is rotated for lower-half pips.
      return '<path d="M0-11C-2-7-9-3-9 3C-9 8-3 10-0.5 6C-0.4 9-2 12-4 13H4C2 12 0.4 9 0.5 6C3 10 9 8 9 3C9-3 2-7 0-11Z" fill="' + $Color + '" transform="' + $transform + '"/>'
    }
    'clubs' {
      # One compound path is rasterized as one filled silhouette. Separate
      # overlapping circles can expose anti-alias seams on OpenHarmony.
      $clubPath = 'M0-10A5 5 0 1 1 0 0A5 5 0 1 1 0-10Z ' +
        'M-5-3A5 5 0 1 1-5 7A5 5 0 1 1-5-3Z ' +
        'M5-3A5 5 0 1 1 5 7A5 5 0 1 1 5-3Z ' +
        'M-2.5-3.5H2.5V4H2C2 8 3 10 5 12H-5C-3 10-2 8-2 4H-2.5Z'
      return '<path d="' + $clubPath + '" fill="' + $Color + '" transform="' + $transform + '"/>'
    }
    default { throw "Unknown suit: $Suit" }
  }
}

function Get-CornerIndices([string]$Suit, [string]$RankLabel, [string]$Ink) {
  # Phone-legibility sizes approved on 2026-09-02. The two-character rank
  # needs a slightly smaller em size to remain inside the corner index column.
  $rankSize = if ($RankLabel -eq '10') { 10.4 } else { 12.0 }
  $rankPath = Get-RankPath $RankLabel $rankSize 6.8 3.2
  $suit = Get-SuitMarkup $Suit $Ink 6.8 17.4 0.36
  $top = '<path d="' + $rankPath + '" fill="' + $Ink + '"/>' + $suit
  return '<g>' + $top + '</g><g transform="rotate(180 22.5 34)">' + $top + '</g>'
}

function Get-PipLayout([int]$Rank) {
  switch ($Rank) {
    2 { return @(@(22.5, 17, 0), @(22.5, 51, 1)) }
    3 { return @(@(22.5, 16, 0), @(22.5, 34, 0), @(22.5, 52, 1)) }
    4 { return @(@(16.3, 18, 0), @(28.7, 18, 0), @(16.3, 50, 1), @(28.7, 50, 1)) }
    5 { return @(@(16.3, 17, 0), @(28.7, 17, 0), @(22.5, 34, 0), @(16.3, 51, 1), @(28.7, 51, 1)) }
    6 { return @(@(16.3, 15, 0), @(28.7, 15, 0), @(16.3, 34, 0), @(28.7, 34, 0), @(16.3, 53, 1), @(28.7, 53, 1)) }
    7 { return @(@(16.3, 14, 0), @(28.7, 14, 0), @(22.5, 24, 0), @(16.3, 34, 0), @(28.7, 34, 0), @(16.3, 54, 1), @(28.7, 54, 1)) }
    8 { return @(@(16.3, 14, 0), @(28.7, 14, 0), @(22.5, 24, 0), @(16.3, 34, 0), @(28.7, 34, 0), @(22.5, 44, 1), @(16.3, 54, 1), @(28.7, 54, 1)) }
    9 { return @(@(16.3, 13, 0), @(28.7, 13, 0), @(16.3, 27, 0), @(28.7, 27, 0), @(22.5, 34, 0), @(16.3, 41, 1), @(28.7, 41, 1), @(16.3, 55, 1), @(28.7, 55, 1)) }
    10 { return @(@(16.3, 12, 0), @(28.7, 12, 0), @(22.5, 20, 0), @(16.3, 27, 0), @(28.7, 27, 0), @(16.3, 41, 1), @(28.7, 41, 1), @(22.5, 48, 1), @(16.3, 56, 1), @(28.7, 56, 1)) }
    default { throw "Unsupported pip rank: $Rank" }
  }
}

function Get-NumberPips([string]$Suit, [string]$Ink, [int]$Rank) {
  $parts = [System.Collections.Generic.List[string]]::new()
  foreach ($pip in (Get-PipLayout $Rank)) {
    $parts.Add((Get-SuitMarkup $Suit $Ink $pip[0] $pip[1] 0.34 ([bool]$pip[2])))
  }
  return $parts -join "`n  "
}

function Get-OniroLogoMarkup([double]$CenterX, [double]$CenterY, [double]$Scale) {
  $transform = 'translate({0} {1}) scale({2})' -f
    (Format-Number $CenterX), (Format-Number $CenterY), (Format-Number $Scale)
  return @"
<g transform="$transform">
  <path d="M-15-4L-9-11L-3-7L-5 1L-12 8L-17 5Z" fill="#00BCD4"/>
  <path d="M-8-13L-1-16L5-13L4-6L-2-2L-7-6Z" fill="#FFEB3B"/>
  <path d="M3-16L10-15L14-10L10-5L4-6L1-11Z" fill="#F20CB2"/>
  <path d="M11-7L16-3L16 4L11 7L6 4L6-2Z" fill="#5725B7"/>
  <path d="M15 3L17 10L13 15L6 14L4 9L8 4Z" fill="#FFEB3B"/>
  <path d="M7 13L2 17L-6 16L-8 10L-4 5L3 7Z" fill="#00BCD4"/>
  <path d="M-5 15L-12 13L-15 7L-11 2L-5 3L-2 9Z" fill="#F20CB2"/>
  <path d="M-15 6L-17 0L-14-6L-8-5L-5 0L-9 5Z" fill="#5725B7"/>
</g>
"@
}

function Get-CourtHalf([string]$RankLabel, [string]$Ink) {
  if ($RankLabel -eq 'J') {
    return @"
<g>
  <path d="M16 31L17 24L28 24L29 31L25 34H20Z" fill="#2F64B3" stroke="#171717" stroke-width="0.45"/>
  <path d="M18 27L27 31" stroke="#F2C94C" stroke-width="2.1"/>
  <circle cx="22.5" cy="19" r="4.2" fill="#F1C7A5" stroke="#171717" stroke-width="0.45"/>
  <path d="M18.2 18C18.3 13.5 26.7 13.5 26.8 18L25.5 16L23 14.8L19.5 16Z" fill="#4B2E20"/>
  <path d="M17.5 15L22 10.5L27.5 14L25.5 16.5L20 15.5Z" fill="#2F64B3" stroke="#171717" stroke-width="0.45"/>
  <circle cx="26.7" cy="13.8" r="1.2" fill="#C62828"/>
  <path d="M27.5 23L31 12" stroke="#C9A227" stroke-width="1.2"/>
  <path d="M29.5 12L32.2 10.5L31 14Z" fill="#D9E3F0" stroke="#171717" stroke-width="0.35"/>
  <path d="M20.5 20.2Q22.5 21.5 24.5 20.2" fill="none" stroke="#8B4A3A" stroke-width="0.45"/>
</g>
"@
  }
  if ($RankLabel -eq 'Q') {
    return @"
<g>
  <path d="M15.5 32L17 24L28 24L29.5 32L25 34H20Z" fill="#B53978" stroke="#171717" stroke-width="0.45"/>
  <path d="M18 25L22.5 32L27 25" fill="#2F64B3" stroke="#F2C94C" stroke-width="0.7"/>
  <path d="M17.5 17C17 23 19 25 22.5 25S28 23 27.5 17Z" fill="#6A3E24"/>
  <circle cx="22.5" cy="18.5" r="4.1" fill="#F1C7A5" stroke="#171717" stroke-width="0.45"/>
  <path d="M18.5 17.2C18.9 14.9 20.2 13.9 22.4 13.7C22.1 15.2 20.7 16.5 18.5 17.2ZM26.5 17.2C26.1 14.9 24.8 13.9 22.6 13.7C22.9 15.2 24.3 16.5 26.5 17.2Z" fill="#6A3E24"/>
  <path d="M17.5 15L18.5 10L21 13L22.5 9L24 13L27 10L27.5 15Z" fill="#F2C94C" stroke="#171717" stroke-width="0.45"/>
  <circle cx="22.5" cy="10.6" r="0.8" fill="#C62828"/>
  <path d="M20.5 20Q22.5 21.2 24.5 20" fill="none" stroke="#8B4A3A" stroke-width="0.45"/>
  <path d="M16.5 27L13 20" stroke="#397C4A" stroke-width="1"/>
  <circle cx="12.7" cy="18.8" r="1.8" fill="$Ink"/>
  <path d="M12.6 18L10.8 16.6M12.8 18L14.7 16.7" stroke="#397C4A" stroke-width="0.6"/>
</g>
"@
  }
  return @"
<g>
  <path d="M15.5 32L17 24L28 24L29.5 32L25 34H20Z" fill="#C43C34" stroke="#171717" stroke-width="0.45"/>
  <path d="M18 25L22.5 32L27 25" fill="#2F64B3" stroke="#F2C94C" stroke-width="0.7"/>
  <circle cx="22.5" cy="18.5" r="4.2" fill="#F1C7A5" stroke="#171717" stroke-width="0.45"/>
  <path d="M18.4 18C18.5 14 26.5 14 26.6 18L25.5 16L22.5 14.8L19.5 16Z" fill="#3A251B"/>
  <path d="M19 20C19.5 25 25.5 25 26 20C24 21 21 21 19 20Z" fill="#6A3E24"/>
  <path d="M17.4 15L18.5 9.5L21 12.5L22.5 8.5L24 12.5L27 9.5L27.6 15Z" fill="#F2C94C" stroke="#171717" stroke-width="0.45"/>
  <circle cx="22.5" cy="10.2" r="0.8" fill="#C62828"/>
  <path d="M27.8 28L31 11" stroke="#D9E3F0" stroke-width="1.5"/>
  <path d="M29.5 12L32 9L31.8 14Z" fill="#D9E3F0" stroke="#171717" stroke-width="0.35"/>
  <path d="M29 23L31 25" stroke="#F2C94C" stroke-width="1"/>
</g>
"@
}

function Get-CourtMarkup([string]$RankLabel, [string]$Suit, [string]$Ink) {
  $half = Get-CourtHalf $RankLabel $Ink
  $centerSuit = Get-SuitMarkup $Suit $Ink 22.5 34 0.22
  return @"
<rect x="11.3" y="5.5" width="22.4" height="57" rx="1.8" fill="#F8E8B8" stroke="#C9A227" stroke-width="0.65"/>
$half
<g transform="rotate(180 22.5 34)">$half</g>
$centerSuit
"@
}

function Get-CardSvg([string]$Suit, [string]$RankLabel, [int]$NumericRank) {
  $ink = if ($Suit -eq 'hearts' -or $Suit -eq 'diamonds') { '#C62828' } else { '#171717' }
  $corners = Get-CornerIndices $Suit $RankLabel $ink
  if ($NumericRank -eq 1) {
    $center = Get-OniroLogoMarkup 22.5 34 0.72
  } elseif ($NumericRank -le 10) {
    $center = Get-NumberPips $Suit $ink $NumericRank
  } else {
    $center = Get-CourtMarkup $RankLabel $Suit $ink
  }
  return @"
<svg xmlns="http://www.w3.org/2000/svg" width="45" height="68" viewBox="0 0 45 68" preserveAspectRatio="xMidYMid meet">
  <title>$RankLabel of $Suit</title>
  <rect x="0.5" y="0.5" width="44" height="67" rx="6.5" fill="#FFFDF8" stroke="#C9C7C2"/>
  $center
  $corners
</svg>
"@
}

function Set-CardCornerIndices(
  [string]$SourceSvg,
  [string]$Suit,
  [string]$RankLabel
) {
  # Canonical cards contain post-generation artwork refinements. Replace only
  # their final corner-index pair so preview generation preserves everything
  # else byte-for-byte within the SVG body.
  $cornerStart = $SourceSvg.LastIndexOf('  <g><path d="', [System.StringComparison]::Ordinal)
  $outerGroupEnd = $SourceSvg.LastIndexOf('  </g>', [System.StringComparison]::Ordinal)
  if ($cornerStart -lt 0 -or $outerGroupEnd -le $cornerStart) {
    throw 'Could not locate the canonical card corner indices.'
  }

  $ink = if ($Suit -eq 'hearts' -or $Suit -eq 'diamonds') { '#C62828' } else { '#171717' }
  $corners = '  ' + (Get-CornerIndices $Suit $RankLabel $ink) + "`n"
  return $SourceSvg.Substring(0, $cornerStart) + $corners + $SourceSvg.Substring($outerGroupEnd)
}

function Get-CardBackSvg() {
  return @"
<svg xmlns="http://www.w3.org/2000/svg" width="45" height="68" viewBox="0 0 45 68" preserveAspectRatio="xMidYMid meet">
  <title>Card back</title>
  <rect x="0.5" y="0.5" width="44" height="67" rx="6.5" fill="#235A96" stroke="#1C4776"/>
  <path d="M22.5 24L32.5 34L22.5 44L12.5 34Z" fill="#D8E6F7"/>
</svg>
"@
}

function Get-InnerSvg([string]$Svg) {
  $match = [regex]::Match($Svg, '<svg[^>]*>([\s\S]*)</svg>')
  if (-not $match.Success) { throw 'Could not extract SVG contents.' }
  return $match.Groups[1].Value
}

$outputPath = [System.IO.Path]::GetFullPath($OutputDirectory)
$sourcePath = if ([string]::IsNullOrWhiteSpace($SourceCardDirectory)) {
  ''
} else {
  [System.IO.Path]::GetFullPath($SourceCardDirectory)
}
if ($sourcePath -and $sourcePath.Equals($outputPath, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw 'SourceCardDirectory and OutputDirectory must be different directories.'
}

[System.IO.Directory]::CreateDirectory($outputPath) | Out-Null
$suits = @('clubs', 'diamonds', 'hearts', 'spades')
$ranks = @(
  @{ File = 'ace'; Label = 'A'; Value = 1 },
  @{ File = '2'; Label = '2'; Value = 2 },
  @{ File = '3'; Label = '3'; Value = 3 },
  @{ File = '4'; Label = '4'; Value = 4 },
  @{ File = '5'; Label = '5'; Value = 5 },
  @{ File = '6'; Label = '6'; Value = 6 },
  @{ File = '7'; Label = '7'; Value = 7 },
  @{ File = '8'; Label = '8'; Value = 8 },
  @{ File = '9'; Label = '9'; Value = 9 },
  @{ File = '10'; Label = '10'; Value = 10 },
  @{ File = 'jack'; Label = 'J'; Value = 11 },
  @{ File = 'queen'; Label = 'Q'; Value = 12 },
  @{ File = 'king'; Label = 'K'; Value = 13 }
)

$cardSvgs = @{}
foreach ($suit in $suits) {
  foreach ($rank in $ranks) {
    $fileName = '{0}_of_{1}.svg' -f $rank.File, $suit
    if ($sourcePath) {
      $sourceFile = Join-Path $sourcePath $fileName
      if (-not [System.IO.File]::Exists($sourceFile)) { throw "Missing source card: $sourceFile" }
      $svg = Set-CardCornerIndices ([System.IO.File]::ReadAllText($sourceFile)) $suit $rank.Label
    } else {
      $svg = Convert-ToTwoThreeCardSvg (Get-CardSvg $suit $rank.Label $rank.Value)
    }
    [System.IO.File]::WriteAllText((Join-Path $outputPath $fileName), $svg, $utf8NoBom)
    $cardSvgs[$fileName] = $svg
  }
}
if ($sourcePath) {
  $sourceBackFile = Join-Path $sourcePath 'card_back.svg'
  if (-not [System.IO.File]::Exists($sourceBackFile)) { throw "Missing source card: $sourceBackFile" }
  $backSvg = [System.IO.File]::ReadAllText($sourceBackFile)
} else {
  $backSvg = Convert-ToTwoThreeCardSvg (Get-CardBackSvg)
}
[System.IO.File]::WriteAllText((Join-Path $outputPath 'card_back.svg'), $backSvg, $utf8NoBom)

# Generate the four user-selected alternative backs alongside the traditional
# deck assets. Their canonical geometry remains owned by the variation
# generator, whose selected mode deliberately omits the other experiments.
$cardBackGenerator = Join-Path $PSScriptRoot 'generate-card-back-variations.ps1'
$cardBackGeneratorOutput = & $cardBackGenerator -OutputDirectory $outputPath -SelectedOnly
if ($cardBackGeneratorOutput) { Write-Verbose ($cardBackGeneratorOutput -join ' ') }

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
  for ($column = 0; $column -lt $ranks.Count; $column++) {
    $fileName = '{0}_of_{1}.svg' -f $ranks[$column].File, $suits[$row]
    $x = $left + ($column * ($cardWidth + $columnGap))
    $y = $top + ($row * ($cardHeight + $rowGap))
    $inner = Get-InnerSvg $cardSvgs[$fileName]
    $sheet.Add(('<g transform="translate({0} {1}) scale({2})">{3}</g>' -f
      (Format-Number $x), (Format-Number $y), (Format-Number $scale), $inner))
  }
}
$backX = $left + (6 * ($cardWidth + $columnGap))
$backY = $top + (4 * ($cardHeight + $rowGap))
$sheet.Add(('<g transform="translate({0} {1}) scale({2})">{3}</g>' -f
  (Format-Number $backX), (Format-Number $backY), (Format-Number $scale), (Get-InnerSvg $backSvg)))
$sheet.Add(('<text x="{0}" y="{1}" fill="#FFFFFF" font-family="Arial, sans-serif" font-size="17" text-anchor="middle">card back</text>' -f
  (Format-Number ($backX + ($cardWidth / 2))), (Format-Number ($backY + $cardHeight + 24))))
$sheet.Add('</svg>')
[System.IO.File]::WriteAllText((Join-Path $outputPath 'all-cards.svg'), ($sheet -join "`n"), $utf8NoBom)

if ($sourcePath) {
  Write-Output 'Generated larger-index preview cards and four selected card backs while preserving canonical artwork.'
} else {
  Write-Output 'Generated traditional pip cards, mirrored vector court cards, and four selected card backs.'
}
