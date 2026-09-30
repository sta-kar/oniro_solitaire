param(
  [Parameter(Mandatory = $true)]
  [string]$OutputDirectory,

  [switch]$SelectedOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)

function Convert-ToTwoThreeCardSvg([string]$Svg) {
  if ($Svg.Contains('data-card-aspect="2:3"')) { return $Svg }

  $sourceRoot = '<svg xmlns="http://www.w3.org/2000/svg" width="45" height="68" viewBox="0 0 45 68" preserveAspectRatio="xMidYMid meet">'
  $targetRoot = '<svg xmlns="http://www.w3.org/2000/svg" width="45" height="67.5" viewBox="0 0 45 67.5" preserveAspectRatio="xMidYMid meet" data-card-aspect="2:3">'
  if (-not $Svg.Contains($sourceRoot)) { throw 'Card SVG does not use the expected 45-by-68 source viewport.' }

  $result = $Svg.Replace($sourceRoot, $targetRoot)
  $result = $result.Replace('</title>', "</title>`n  <g transform=`"scale(1 0.9926470588235294)`" data-source-viewBox=`"0 0 45 68`">")
  $closingIndex = $result.LastIndexOf('</svg>')
  if ($closingIndex -lt 0) { throw 'Card SVG is missing its closing element.' }
  return $result.Substring(0, $closingIndex) + "  </g>`n" + $result.Substring($closingIndex)
}

function New-CardSvg(
  [string]$Title,
  [string]$Definitions,
  [string]$Body,
  [string]$Border,
  [string]$InnerBorder = ''
) {
  return @"
<svg xmlns="http://www.w3.org/2000/svg" width="45" height="68" viewBox="0 0 45 68" preserveAspectRatio="xMidYMid meet">
  <title>$Title</title>
  <defs>
    <clipPath id="clip"><rect x="0.5" y="0.5" width="44" height="67" rx="6.5"/></clipPath>
    $Definitions
  </defs>
  <g clip-path="url(#clip)">
    $Body
  </g>
  <rect x="0.5" y="0.5" width="44" height="67" rx="6.5" fill="none" stroke="$Border"/>
  $InnerBorder
</svg>
"@
}

function Get-InnerSvg([string]$Svg) {
  $match = [regex]::Match($Svg, '<svg[^>]*>([\s\S]*)</svg>')
  if (-not $match.Success) { throw 'Could not extract SVG contents.' }
  return $match.Groups[1].Value
}

[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$assets = [ordered]@{}

# Oniro Orbit 01: segmented concentric rings.
$assets['oniro_orbit_01_classic.svg'] = New-CardSvg 'Oniro Orbit 01 — Classic' @'
<radialGradient id="bg" cx="50%" cy="45%" r="70%"><stop stop-color="#30155E"/><stop offset="1" stop-color="#0E041A"/></radialGradient>
'@ @'
<rect width="45" height="68" fill="url(#bg)"/>
<circle cx="22.5" cy="34" r="15.5" fill="none" stroke="#FFFFFF" stroke-opacity="0.12"/>
<circle cx="22.5" cy="34" r="12" fill="none" stroke="#00C9E5" stroke-width="4" stroke-dasharray="17 9 11 8" transform="rotate(-25 22.5 34)"/>
<circle cx="22.5" cy="34" r="12" fill="none" stroke="#FF2CB8" stroke-width="4" stroke-dasharray="8 27 13 27" transform="rotate(42 22.5 34)"/>
<circle cx="22.5" cy="34" r="12" fill="none" stroke="#FFEE52" stroke-width="4" stroke-dasharray="7 32 10 26" transform="rotate(104 22.5 34)"/>
<circle cx="22.5" cy="34" r="6.8" fill="#08020E" stroke="#7133C7"/>
<circle cx="22.5" cy="34" r="2" fill="#FFFFFF"/>
<g fill="#FFFFFF" opacity="0.48"><circle cx="7" cy="11" r="0.6"/><circle cx="38" cy="15" r="0.6"/><circle cx="8" cy="56" r="0.6"/><circle cx="37" cy="53" r="0.6"/></g>
'@ '#633092' '<rect x="2.5" y="2.5" width="40" height="63" rx="5" fill="none" stroke="#FFFFFF" stroke-opacity="0.18"/>'

# Oniro Orbit 02: gyroscope ellipses.
$assets['oniro_orbit_02_gyroscope.svg'] = New-CardSvg 'Oniro Orbit 02 — Gyroscope' @'
<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#071832"/><stop offset="1" stop-color="#28104B"/></linearGradient>
'@ @'
<rect width="45" height="68" fill="url(#bg)"/>
<g fill="none" stroke-width="1.7"><ellipse cx="22.5" cy="34" rx="17" ry="7" stroke="#00D4DF" transform="rotate(22 22.5 34)"/><ellipse cx="22.5" cy="34" rx="17" ry="7" stroke="#FF35B9" transform="rotate(-22 22.5 34)"/><ellipse cx="22.5" cy="34" rx="16" ry="6.5" stroke="#FFE45C" transform="rotate(90 22.5 34)"/></g>
<circle cx="22.5" cy="34" r="5.8" fill="#120621" stroke="#FFFFFF" stroke-width="0.8"/>
<path d="M22.5 29L27.5 34L22.5 39L17.5 34Z" fill="#6C38C5"/>
<g><circle cx="7.2" cy="27.7" r="1.7" fill="#00D4DF"/><circle cx="38" cy="28.5" r="1.7" fill="#FF35B9"/><circle cx="22.5" cy="18" r="1.7" fill="#FFE45C"/></g>
<g fill="#FFFFFF" opacity="0.5"><circle cx="9" cy="10" r="0.45"/><circle cx="35" cy="13" r="0.45"/><circle cx="12" cy="57" r="0.45"/><circle cx="38" cy="52" r="0.45"/></g>
'@ '#4A68A7'

# Oniro Orbit 03: offset nucleus and satellites.
$assets['oniro_orbit_03_satellite.svg'] = New-CardSvg 'Oniro Orbit 03 — Satellite' @'
<radialGradient id="bg" cx="42%" cy="48%" r="80%"><stop stop-color="#4A123F"/><stop offset="0.55" stop-color="#231139"/><stop offset="1" stop-color="#090511"/></radialGradient>
'@ @'
<rect width="45" height="68" fill="url(#bg)"/>
<circle cx="19.5" cy="36" r="10" fill="#07030A" stroke="#6A35BA"/>
<circle cx="19.5" cy="36" r="15.5" fill="none" stroke="#FF2CB8" stroke-width="1.4" stroke-dasharray="30 12 8 48" transform="rotate(20 19.5 36)"/>
<circle cx="19.5" cy="36" r="18.5" fill="none" stroke="#00C9E5" stroke-width="1" stroke-dasharray="14 18 27 58" transform="rotate(-35 19.5 36)"/>
<circle cx="28" cy="23.5" r="3.4" fill="#FFEE52"/><circle cx="33.7" cy="44.5" r="2.6" fill="#00C9E5"/><circle cx="7.5" cy="43" r="2.2" fill="#FF2CB8"/>
<circle cx="19.5" cy="36" r="2.3" fill="#FFFFFF"/>
<path d="M7 15Q19 7 35 13" fill="none" stroke="#FFFFFF" stroke-opacity="0.18"/><path d="M9 57Q24 64 38 55" fill="none" stroke="#FFFFFF" stroke-opacity="0.18"/>
'@ '#74265E'

# Oniro Orbit 04: orbital flower.
$assets['oniro_orbit_04_bloom.svg'] = New-CardSvg 'Oniro Orbit 04 — Bloom' @'
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#24104C"/><stop offset="1" stop-color="#0B061A"/></linearGradient>
'@ @'
<rect width="45" height="68" fill="url(#bg)"/>
<g fill="none" stroke-width="4" opacity="0.95"><ellipse cx="22.5" cy="24" rx="5" ry="11" stroke="#00C9E5"/><ellipse cx="22.5" cy="44" rx="5" ry="11" stroke="#FF2CB8"/><ellipse cx="12.5" cy="34" rx="11" ry="5" stroke="#FFE952"/><ellipse cx="32.5" cy="34" rx="11" ry="5" stroke="#6832BD"/></g>
<circle cx="22.5" cy="34" r="8" fill="#0A0310" stroke="#FFFFFF" stroke-opacity="0.5"/>
<circle cx="22.5" cy="34" r="3.2" fill="#FFFFFF"/>
<g fill="#FFFFFF" opacity="0.35"><circle cx="6" cy="9" r="0.5"/><circle cx="39" cy="11" r="0.5"/><circle cx="6" cy="59" r="0.5"/><circle cx="39" cy="57" r="0.5"/></g>
'@ '#6330A0' '<rect x="2.5" y="2.5" width="40" height="63" rx="5" fill="none" stroke="#FFFFFF" stroke-opacity="0.16"/>'

# Oniro Orbit 05: sparse premium minimalism.
$assets['oniro_orbit_05_minimal.svg'] = New-CardSvg 'Oniro Orbit 05 — Minimal' @'
<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#0B0A12"/><stop offset="1" stop-color="#191126"/></linearGradient>
'@ @'
<rect width="45" height="68" fill="url(#bg)"/>
<circle cx="22.5" cy="34" r="16" fill="none" stroke="#FFFFFF" stroke-opacity="0.16" stroke-width="0.7"/>
<circle cx="22.5" cy="34" r="11" fill="none" stroke="#FFFFFF" stroke-opacity="0.32" stroke-width="0.7"/>
<circle cx="22.5" cy="18" r="2.3" fill="#FFEE52"/><circle cx="38.5" cy="34" r="2.3" fill="#6832BD"/><circle cx="22.5" cy="50" r="2.3" fill="#00C9E5"/><circle cx="6.5" cy="34" r="2.3" fill="#FF2CB8"/>
<circle cx="22.5" cy="34" r="6" fill="#020204" stroke="#FFFFFF" stroke-width="0.8"/><circle cx="22.5" cy="34" r="1.5" fill="#FFFFFF"/>
'@ '#3B3248' '<rect x="2.5" y="2.5" width="40" height="63" rx="5" fill="none" stroke="#FFFFFF" stroke-opacity="0.12"/>'

# Emerald Art Deco 01: classic fan.
$assets['emerald_deco_01_fan.svg'] = New-CardSvg 'Emerald Art Deco 01 — Fan' @'
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#073A31"/><stop offset="0.5" stop-color="#0A5B48"/><stop offset="1" stop-color="#052A25"/></linearGradient>
'@ @'
<rect width="45" height="68" fill="url(#bg)"/>
<g fill="none" stroke="#D9B85B" stroke-width="0.8"><path d="M3 26Q22.5 3 42 26"/><path d="M7 27Q22.5 9 38 27"/><path d="M11 28Q22.5 15 34 28"/><path d="M3 42Q22.5 65 42 42"/><path d="M7 41Q22.5 59 38 41"/><path d="M11 40Q22.5 53 34 40"/><path d="M22.5 4V64"/><path d="M4 34H41"/></g>
<path d="M22.5 25L31 34L22.5 43L14 34Z" fill="#062C25" stroke="#F1D47A" stroke-width="1.3"/><path d="M22.5 29L27 34L22.5 39L18 34Z" fill="#D9B85B"/><circle cx="22.5" cy="34" r="1.3" fill="#FFF4C6"/>
'@ '#C7A74F' '<rect x="2.5" y="2.5" width="40" height="63" rx="5" fill="none" stroke="#D9B85B" stroke-width="0.8"/>'

# Emerald Art Deco 02: stepped diamonds.
$assets['emerald_deco_02_steps.svg'] = New-CardSvg 'Emerald Art Deco 02 — Steps' @'
<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#022D25"/><stop offset="1" stop-color="#0C6A52"/></linearGradient>
'@ @'
<rect width="45" height="68" fill="url(#bg)"/>
<g fill="none" stroke="#E3C46E"><path d="M5 10H14V6H31V10H40V22H35V29H30"/><path d="M5 58H14V62H31V58H40V46H35V39H30"/><path d="M15 18L22.5 10L30 18L22.5 26Z"/><path d="M15 50L22.5 58L30 50L22.5 42Z"/></g>
<path d="M22.5 23L33 34L22.5 45L12 34Z" fill="#04362C" stroke="#E3C46E" stroke-width="1.2"/><path d="M22.5 27L29 34L22.5 41L16 34Z" fill="#0D8B68"/><path d="M22.5 30L26 34L22.5 38L19 34Z" fill="#FFE798"/>
'@ '#C9A94D' '<rect x="2" y="2" width="41" height="64" rx="5" fill="none" stroke="#E3C46E" stroke-width="0.7"/>'

# Emerald Art Deco 03: sunburst.
$assets['emerald_deco_03_sunburst.svg'] = New-CardSvg 'Emerald Art Deco 03 — Sunburst' @'
<radialGradient id="bg" cx="50%" cy="50%" r="75%"><stop stop-color="#0E7459"/><stop offset="1" stop-color="#022A23"/></radialGradient>
'@ @'
<rect width="45" height="68" fill="url(#bg)"/>
<g stroke="#E6C968" stroke-width="0.8"><path d="M22.5 34L22.5 5"/><path d="M22.5 34L35 8"/><path d="M22.5 34L42 18"/><path d="M22.5 34L43 34"/><path d="M22.5 34L42 50"/><path d="M22.5 34L35 60"/><path d="M22.5 34L22.5 63"/><path d="M22.5 34L10 60"/><path d="M22.5 34L3 50"/><path d="M22.5 34L2 34"/><path d="M22.5 34L3 18"/><path d="M22.5 34L10 8"/></g>
<circle cx="22.5" cy="34" r="13" fill="#063A2F" stroke="#E6C968"/><circle cx="22.5" cy="34" r="9" fill="#0B604B" stroke="#E6C968"/><path d="M22.5 25L31 34L22.5 43L14 34Z" fill="#E6C968"/><path d="M22.5 29L27 34L22.5 39L18 34Z" fill="#073E33"/>
'@ '#D2B455'

# Emerald Art Deco 04: ivory ballroom.
$assets['emerald_deco_04_ivory.svg'] = New-CardSvg 'Emerald Art Deco 04 — Ivory' @'
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#FFF8DD"/><stop offset="1" stop-color="#E8D89E"/></linearGradient>
'@ @'
<rect width="45" height="68" fill="url(#bg)"/>
<g fill="none" stroke="#0A5C46" stroke-width="1"><path d="M4 24Q22.5 2 41 24"/><path d="M8 26Q22.5 9 37 26"/><path d="M12 28Q22.5 16 33 28"/><path d="M4 44Q22.5 66 41 44"/><path d="M8 42Q22.5 59 37 42"/><path d="M12 40Q22.5 52 33 40"/></g>
<path d="M22.5 20L36 34L22.5 48L9 34Z" fill="#0A5C46" stroke="#B58E28" stroke-width="1.2"/><path d="M22.5 25L31 34L22.5 43L14 34Z" fill="#FFF8DD"/><path d="M22.5 29L27 34L22.5 39L18 34Z" fill="#B58E28"/>
'@ '#0A5C46' '<rect x="2.5" y="2.5" width="40" height="63" rx="5" fill="none" stroke="#B58E28" stroke-width="0.8"/>'

# Emerald Art Deco 05: nocturne columns.
$assets['emerald_deco_05_nocturne.svg'] = New-CardSvg 'Emerald Art Deco 05 — Nocturne' @'
<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#021713"/><stop offset="1" stop-color="#073D31"/></linearGradient>
'@ @'
<rect width="45" height="68" fill="url(#bg)"/>
<g fill="#B9963B"><rect x="5" y="7" width="2" height="54"/><rect x="38" y="7" width="2" height="54"/><path d="M4 7H12L8 12Z"/><path d="M33 7H41L37 12Z"/><path d="M4 61H12L8 56Z"/><path d="M33 61H41L37 56Z"/></g>
<g fill="none" stroke="#E8CF7A" stroke-width="0.8"><path d="M8 17H15L22.5 9L30 17H37"/><path d="M8 51H15L22.5 59L30 51H37"/><path d="M10 24L22.5 34L35 24"/><path d="M10 44L22.5 34L35 44"/></g>
<circle cx="22.5" cy="34" r="10" fill="#06281F" stroke="#B9963B"/><path d="M22.5 27L29 34L22.5 41L16 34Z" fill="#E8CF7A"/><circle cx="22.5" cy="34" r="2" fill="#0A5C46"/>
'@ '#9E7B2C' '<rect x="2.5" y="2.5" width="40" height="63" rx="5" fill="none" stroke="#B9963B" stroke-width="0.8"/>'

# Prism Mosaic 01: violet shards.
$assets['prism_mosaic_01_violet.svg'] = New-CardSvg 'Prism Mosaic 01 — Violet' '' @'
<rect width="45" height="68" fill="#211044"/>
<g stroke="#FFFFFF" stroke-opacity="0.14" stroke-width="0.5"><path d="M0 0L17 13L0 28Z" fill="#562FA8"/><path d="M0 0L17 13L29 0Z" fill="#7834C9"/><path d="M29 0L17 13L35 20L45 5L45 0Z" fill="#2843A8"/><path d="M0 28L17 13L20 33L5 41Z" fill="#17608F"/><path d="M17 13L35 20L20 33Z" fill="#A4259F"/><path d="M35 20L45 5L45 34L20 33Z" fill="#6C32CC"/><path d="M0 28L5 41L0 56Z" fill="#6D34CA"/><path d="M5 41L20 33L28 51L13 58Z" fill="#2944AC"/><path d="M20 33L45 34L37 47L28 51Z" fill="#C12B96"/><path d="M45 34L45 58L37 47Z" fill="#17608F"/><path d="M0 56L13 58L21 68H0Z" fill="#29419D"/><path d="M13 58L28 51L36 68H21Z" fill="#6D34CA"/><path d="M28 51L37 47L45 58L45 68H36Z" fill="#5630A8"/></g>
<path d="M22.5 23L32 34L22.5 45L13 34Z" fill="#130823" stroke="#F3D6FF" stroke-width="1.2"/><path d="M22.5 27L28.5 34L22.5 41L16.5 34Z" fill="#7B4DFF" stroke="#00D7EA" stroke-width="0.8"/>
'@ '#B477E3'

# Prism Mosaic 02: ocean glass.
$assets['prism_mosaic_02_ocean.svg'] = New-CardSvg 'Prism Mosaic 02 — Ocean' '' @'
<rect width="45" height="68" fill="#082D4D"/>
<g stroke="#C8FAFF" stroke-opacity="0.16" stroke-width="0.5"><path d="M0 0L11 18L24 0Z" fill="#0D6C86"/><path d="M24 0L11 18L31 24L45 10V0Z" fill="#1C9BA8"/><path d="M0 0L11 18L0 35Z" fill="#164D79"/><path d="M11 18L31 24L18 38L0 35Z" fill="#16B5B5"/><path d="M31 24L45 10L45 38L18 38Z" fill="#2470A6"/><path d="M0 35L18 38L9 58L0 51Z" fill="#146783"/><path d="M18 38L45 38L34 54L9 58Z" fill="#1AA7B8"/><path d="M45 38V68L34 54Z" fill="#164D79"/><path d="M0 51L9 58L15 68H0Z" fill="#1C92A0"/><path d="M9 58L34 54L28 68H15Z" fill="#2072A4"/><path d="M34 54L45 68H28Z" fill="#19B2B2"/></g>
<path d="M22.5 21L34 34L22.5 47L11 34Z" fill="#06243A" stroke="#B9FAFF" stroke-width="1.2"/><path d="M22.5 27L28.5 34L22.5 41L16.5 34Z" fill="#23D7CF"/>
'@ '#54D9DF'

# Prism Mosaic 03: sunset glass.
$assets['prism_mosaic_03_sunset.svg'] = New-CardSvg 'Prism Mosaic 03 — Sunset' '' @'
<rect width="45" height="68" fill="#3D102F"/>
<g stroke="#FFF3D2" stroke-opacity="0.15" stroke-width="0.5"><path d="M0 0L16 9L8 26L0 22Z" fill="#D83B73"/><path d="M16 9L29 0H45L35 20L8 26Z" fill="#F06B4E"/><path d="M0 22L8 26L17 41L0 49Z" fill="#8B2C6A"/><path d="M8 26L35 20L28 40L17 41Z" fill="#EF9B46"/><path d="M35 20L45 12V42L28 40Z" fill="#C43D77"/><path d="M0 49L17 41L24 57L12 68H0Z" fill="#D44C5D"/><path d="M17 41L28 40L39 56L24 57Z" fill="#8F2A72"/><path d="M28 40L45 42V68L39 56Z" fill="#F07A4C"/><path d="M12 68L24 57L39 56L45 68Z" fill="#E8A04A"/></g>
<path d="M22.5 22L33 34L22.5 46L12 34Z" fill="#351026" stroke="#FFE4A6" stroke-width="1.2"/><path d="M22.5 27L29 34L22.5 41L16 34Z" fill="#FFBE55" stroke="#FF4B9A"/>
'@ '#E47765'

# Prism Mosaic 04: dark crystal.
$assets['prism_mosaic_04_dark_crystal.svg'] = New-CardSvg 'Prism Mosaic 04 — Dark Crystal' '' @'
<rect width="45" height="68" fill="#070812"/>
<g stroke="#5FE8F2" stroke-opacity="0.2" stroke-width="0.5"><path d="M0 0L20 15L0 31Z" fill="#151A38"/><path d="M0 0L20 15L35 0Z" fill="#2C1F58"/><path d="M35 0L20 15L45 28V0Z" fill="#0C3E54"/><path d="M0 31L20 15L22 36L0 52Z" fill="#20245A"/><path d="M20 15L45 28L22 36Z" fill="#5D1E75"/><path d="M45 28V53L22 36Z" fill="#123B59"/><path d="M0 52L22 36L17 68H0Z" fill="#421D64"/><path d="M22 36L45 53L45 68H17Z" fill="#182A55"/></g>
<path d="M22.5 18L35 34L22.5 50L10 34Z" fill="#04060B" stroke="#7B4DFF" stroke-width="1.4"/><path d="M22.5 24L30.5 34L22.5 44L14.5 34Z" fill="#24154A" stroke="#00E8F0"/><path d="M22.5 29L26.5 34L22.5 39L18.5 34Z" fill="#FF2CB8"/>
'@ '#4B3A82'

# Prism Mosaic 05: frosted glass.
$assets['prism_mosaic_05_frost.svg'] = New-CardSvg 'Prism Mosaic 05 — Frost' '' @'
<rect width="45" height="68" fill="#E9F7FF"/>
<g stroke="#FFFFFF" stroke-opacity="0.75" stroke-width="0.7"><path d="M0 0L13 16L0 31Z" fill="#A9D9E8"/><path d="M0 0L13 16L29 0Z" fill="#C7B8E8"/><path d="M29 0L13 16L34 25L45 8V0Z" fill="#8FC9E4"/><path d="M0 31L13 16L20 36L5 47Z" fill="#B9B4E6"/><path d="M13 16L34 25L20 36Z" fill="#D9A7D7"/><path d="M34 25L45 8V40L20 36Z" fill="#9BCFE4"/><path d="M0 31L5 47L0 61Z" fill="#A2D8E2"/><path d="M5 47L20 36L31 52L16 68H0V61Z" fill="#C6B7E7"/><path d="M20 36L45 40V68H16L31 52Z" fill="#A9D9E8"/></g>
<path d="M22.5 21L34 34L22.5 47L11 34Z" fill="#F9FDFF" stroke="#5C83B8" stroke-width="1.2"/><path d="M22.5 27L28.5 34L22.5 41L16.5 34Z" fill="#B59ADF" stroke="#69C5D8"/>
'@ '#6D94C0'

# Solar Eclipse 01: gold crescent, moon lower-right of sun.
$assets['solar_eclipse_01_gold.svg'] = New-CardSvg 'Solar Eclipse 01 — Gold' @'
<radialGradient id="bg" cx="50%" cy="50%" r="70%"><stop stop-color="#343139"/><stop offset="1" stop-color="#111014"/></radialGradient><radialGradient id="sun"><stop stop-color="#FFF4A0"/><stop offset="0.65" stop-color="#F5B942"/><stop offset="1" stop-color="#E66B2E"/></radialGradient>
'@ @'
<rect width="45" height="68" fill="url(#bg)"/>
<g stroke="#E8B84A" stroke-width="0.8" opacity="0.7"><path d="M20.5 6V14"/><path d="M20.5 52V62"/><path d="M2 32H10"/><path d="M31 32H41"/><path d="M7 15L13 21"/><path d="M29 43L36 50"/><path d="M34 14L28 20"/><path d="M12 44L6 50"/></g>
<circle cx="20.5" cy="32" r="13.5" fill="none" stroke="#E8B84A" stroke-opacity="0.38" stroke-dasharray="2 2"/><circle cx="20.5" cy="32" r="10.5" fill="url(#sun)"/><circle cx="25.5" cy="37" r="9.2" fill="#111014"/><path d="M12 35Q18 43 25 43" fill="none" stroke="#FFF4A0" stroke-width="1.1" stroke-linecap="round"/>
'@ '#B98631'

# Solar Eclipse 02: copper corona, moon lower-right.
$assets['solar_eclipse_02_copper.svg'] = New-CardSvg 'Solar Eclipse 02 — Copper' @'
<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#24100D"/><stop offset="1" stop-color="#080607"/></linearGradient><radialGradient id="sun"><stop stop-color="#FFD08A"/><stop offset="0.6" stop-color="#D86A32"/><stop offset="1" stop-color="#8D2C20"/></radialGradient>
'@ @'
<rect width="45" height="68" fill="url(#bg)"/>
<circle cx="20" cy="32" r="15" fill="none" stroke="#C46C38" stroke-width="1" stroke-dasharray="1 2"/><circle cx="20" cy="32" r="12" fill="none" stroke="#F0A357" stroke-opacity="0.5"/><circle cx="20" cy="32" r="9.5" fill="url(#sun)"/><circle cx="25" cy="37" r="8.5" fill="#080607"/>
<g fill="#F0A357"><circle cx="20" cy="12" r="1"/><circle cx="40" cy="32" r="1"/><circle cx="20" cy="52" r="1"/><circle cx="3" cy="32" r="1"/></g><path d="M9 45Q20 57 34 49" fill="none" stroke="#C46C38" stroke-width="0.8"/>
'@ '#8D4C2A' '<rect x="2.5" y="2.5" width="40" height="63" rx="5" fill="none" stroke="#C46C38" stroke-opacity="0.45"/>'

# Solar Eclipse 03: blue corona, moon lower-right.
$assets['solar_eclipse_03_blue.svg'] = New-CardSvg 'Solar Eclipse 03 — Blue' @'
<radialGradient id="bg" cx="50%" cy="45%" r="75%"><stop stop-color="#102C53"/><stop offset="1" stop-color="#040A17"/></radialGradient><radialGradient id="sun"><stop stop-color="#FFFFFF"/><stop offset="0.55" stop-color="#B7EAFF"/><stop offset="1" stop-color="#5FC2EE"/></radialGradient>
'@ @'
<rect width="45" height="68" fill="url(#bg)"/>
<g fill="#B7EAFF" opacity="0.65"><circle cx="7" cy="9" r="0.6"/><circle cx="37" cy="13" r="0.5"/><circle cx="8" cy="56" r="0.5"/><circle cx="37" cy="54" r="0.6"/><circle cx="12" cy="19" r="0.35"/></g>
<circle cx="20.5" cy="32" r="14.5" fill="none" stroke="#7DD8F5" stroke-width="0.8" stroke-dasharray="5 3"/><circle cx="20.5" cy="32" r="10.5" fill="url(#sun)"/><circle cx="25.5" cy="37" r="9" fill="#050B18"/>
<path d="M9 31Q14 42 24 44" fill="none" stroke="#FFFFFF" stroke-width="1.3" stroke-linecap="round"/><path d="M12 49Q22 56 34 48" fill="none" stroke="#5FC2EE" stroke-opacity="0.6"/>
'@ '#4E9AC4'

# Solar Eclipse 04: red giant, moon lower-right.
$assets['solar_eclipse_04_red_giant.svg'] = New-CardSvg 'Solar Eclipse 04 — Red Giant' @'
<radialGradient id="bg" cx="50%" cy="50%" r="70%"><stop stop-color="#42101A"/><stop offset="1" stop-color="#0C0508"/></radialGradient><radialGradient id="sun"><stop stop-color="#FFE38A"/><stop offset="0.45" stop-color="#FF7A37"/><stop offset="1" stop-color="#C91F35"/></radialGradient>
'@ @'
<rect width="45" height="68" fill="url(#bg)"/>
<g stroke="#FF6A38" stroke-linecap="round"><path d="M20 6V14"/><path d="M20 50V61"/><path d="M2 31H11"/><path d="M31 31H43"/><path d="M5 15L12 22"/><path d="M28 43L37 52"/><path d="M35 13L28 20"/><path d="M12 42L4 50"/></g>
<circle cx="20" cy="31" r="12" fill="none" stroke="#FF8D45" stroke-width="2" stroke-opacity="0.35"/><circle cx="20" cy="31" r="9.7" fill="url(#sun)"/><circle cx="25" cy="36.5" r="8.7" fill="#0C0508"/><path d="M11 33Q17 42 25 42" fill="none" stroke="#FFE38A" stroke-width="1.1"/>
'@ '#A32632'

# Solar Eclipse 05: restrained ivory, moon lower-right.
$assets['solar_eclipse_05_minimal.svg'] = New-CardSvg 'Solar Eclipse 05 — Minimal' @'
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#111216"/><stop offset="1" stop-color="#050608"/></linearGradient>
'@ @'
<rect width="45" height="68" fill="url(#bg)"/>
<circle cx="20.5" cy="32" r="16" fill="none" stroke="#FFFFFF" stroke-opacity="0.12"/><circle cx="20.5" cy="32" r="12.5" fill="none" stroke="#D9B85B" stroke-opacity="0.35" stroke-dasharray="2 4"/><circle cx="20.5" cy="32" r="9.5" fill="#F1D98A"/><circle cx="25" cy="36.5" r="8.2" fill="#07080A"/>
<path d="M11.5 33Q15 39.5 21.5 41" fill="none" stroke="#FFF7D2" stroke-width="0.9"/><circle cx="7" cy="12" r="0.7" fill="#F1D98A"/><circle cx="37" cy="55" r="0.7" fill="#F1D98A"/>
'@ '#4A4230' '<rect x="2.5" y="2.5" width="40" height="63" rx="5" fill="none" stroke="#D9B85B" stroke-opacity="0.35"/>'

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$conceptDirectory = Join-Path $repositoryRoot 'card-back-concepts'
$originalSources = [ordered]@{
  'oniro_orbit_00_original.svg' = Join-Path $conceptDirectory '01_oniro_orbit.svg'
  'emerald_deco_00_original.svg' = Join-Path $conceptDirectory '03_emerald_art_deco.svg'
  'prism_mosaic_00_original.svg' = Join-Path $conceptDirectory '08_prism_mosaic.svg'
  'solar_eclipse_00_original.svg' = Join-Path $conceptDirectory '06_solar_eclipse.svg'
}
$originals = [ordered]@{}
foreach ($entry in $originalSources.GetEnumerator()) {
  $content = Get-Content -Raw -LiteralPath $entry.Value
  if ($entry.Key -eq 'solar_eclipse_00_original.svg') {
    # Preserve the approved original design while moving its moon lower-right,
    # matching the placement requirement for the full Solar Eclipse family.
    $content = $content.Replace('<circle cx="25.5" cy="31" r="9.2" fill="#111014"/>', '<circle cx="25.5" cy="37" r="9.2" fill="#111014"/>')
  }
  $content = Convert-ToTwoThreeCardSvg $content
  $originals[$entry.Key] = $content
}
foreach ($name in @($assets.Keys)) {
  $assets[$name] = Convert-ToTwoThreeCardSvg $assets[$name]
}

if ($SelectedOnly) {
  # These are the four alternatives promoted into the main card asset set.
  $selectedAssets = [ordered]@{
    'oniro_orbit_00_original.svg' = $originals['oniro_orbit_00_original.svg']
    'emerald_deco_04_ivory.svg' = $assets['emerald_deco_04_ivory.svg']
    'prism_mosaic_02_ocean.svg' = $assets['prism_mosaic_02_ocean.svg']
    'solar_eclipse_04_red_giant.svg' = $assets['solar_eclipse_04_red_giant.svg']
  }
  foreach ($entry in $selectedAssets.GetEnumerator()) {
    [System.IO.File]::WriteAllText((Join-Path $OutputDirectory $entry.Key), $entry.Value, $utf8)
  }
  Write-Output ('Generated ' + $selectedAssets.Count + ' selected card backs.')
  return
}

foreach ($entry in $originals.GetEnumerator()) {
  [System.IO.File]::WriteAllText((Join-Path $OutputDirectory $entry.Key), $entry.Value, $utf8)
}
foreach ($entry in $assets.GetEnumerator()) {
  [System.IO.File]::WriteAllText((Join-Path $OutputDirectory $entry.Key), $entry.Value, $utf8)
}

$showcaseAssets = [ordered]@{}
$showcaseAssets['oniro_orbit_00_original.svg'] = $originals['oniro_orbit_00_original.svg']
foreach ($name in @($assets.Keys | Where-Object { $_ -like 'oniro_orbit_*' })) { $showcaseAssets[$name] = $assets[$name] }
$showcaseAssets['emerald_deco_00_original.svg'] = $originals['emerald_deco_00_original.svg']
foreach ($name in @($assets.Keys | Where-Object { $_ -like 'emerald_deco_*' })) { $showcaseAssets[$name] = $assets[$name] }
$showcaseAssets['prism_mosaic_00_original.svg'] = $originals['prism_mosaic_00_original.svg']
foreach ($name in @($assets.Keys | Where-Object { $_ -like 'prism_mosaic_*' })) { $showcaseAssets[$name] = $assets[$name] }
$showcaseAssets['solar_eclipse_00_original.svg'] = $originals['solar_eclipse_00_original.svg']
foreach ($name in @($assets.Keys | Where-Object { $_ -like 'solar_eclipse_*' })) { $showcaseAssets[$name] = $assets[$name] }

$names = @($showcaseAssets.Keys)
$labels = @(
  'Orbit 00 · Original','Orbit 01 · Classic','Orbit 02 · Gyroscope','Orbit 03 · Satellite','Orbit 04 · Bloom','Orbit 05 · Minimal',
  'Deco 00 · Original','Deco 01 · Fan','Deco 02 · Steps','Deco 03 · Sunburst','Deco 04 · Ivory','Deco 05 · Nocturne',
  'Prism 00 · Original','Prism 01 · Violet','Prism 02 · Ocean','Prism 03 · Sunset','Prism 04 · Dark Crystal','Prism 05 · Frost',
  'Eclipse 00 · Original','Eclipse 01 · Gold','Eclipse 02 · Copper','Eclipse 03 · Blue','Eclipse 04 · Red Giant','Eclipse 05 · Minimal'
)
$families = @('Oniro Orbit','Emerald Art Deco','Prism Mosaic','Solar Eclipse · moon lower-right')
$scale = 3.2
$sheet = [System.Collections.Generic.List[string]]::new()
$sheet.Add('<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="1120" viewBox="0 0 1200 1120">')
$sheet.Add('<title>Four originals and twenty card-back variations</title>')
$sheet.Add('<rect width="1200" height="1120" fill="#0B6E3F"/>')
$sheet.Add('<text x="55" y="36" fill="#FFFFFF" font-family="Arial, sans-serif" font-size="24" font-weight="700">Solitaire — selected card-back variations</text>')

for ($index = 0; $index -lt $names.Count; $index++) {
  $column = $index % 6
  $row = [Math]::Floor($index / 6)
  $x = 55 + ($column * 185)
  $y = 70 + ($row * 260)
  $inner = Get-InnerSvg $showcaseAssets[$names[$index]]
  $sheet.Add(('<g transform="translate({0} {1}) scale({2})">{3}</g>' -f $x, $y, $scale, $inner))
  $sheet.Add(('<text x="{0}" y="{1}" fill="#FFFFFF" font-family="Arial, sans-serif" font-size="14" text-anchor="middle">{2}</text>' -f ($x + 72), ($y + 238), $labels[$index]))
  if ($column -eq 0) {
    $sheet.Add(('<text x="55" y="{0}" fill="#FFFFFF" fill-opacity="0.72" font-family="Arial, sans-serif" font-size="13">{1}</text>' -f ($y - 8), $families[$row]))
  }
}
$sheet.Add('</svg>')
[System.IO.File]::WriteAllText((Join-Path $OutputDirectory 'all-variations.svg'), ($sheet -join "`n"), $utf8)

Write-Output ('Copied ' + $originals.Count + ' originals, generated ' + $assets.Count + ' variations, and created the SVG showcase.')
