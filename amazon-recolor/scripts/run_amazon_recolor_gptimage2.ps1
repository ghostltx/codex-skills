param(
  [string]$Count = "8+1",
  [string]$SourceDir = "",
  [string]$ReferenceDir = "",
  [string[]]$ReferencePaths = @(),
  [string]$ColorName = "",
  [string]$TargetFinish = "",
  [string]$OutputDir = "",
  [string]$OutputRoot = "",
  [string]$BaseUrl = "https://ai.t8star.org/v1",
  [string]$Model = "gpt-image-2-all",
  [string]$Size = "auto",
  [int]$Parallel = 10,
  [string]$ApiKey = ""
)

$ErrorActionPreference = "Continue"

if ($Count -notmatch '^(\d+)\+(\d+)$') {
  Write-Error "Invalid -Count '$Count'. Expected N+M, for example 8+1."
  exit 1
}

$startedAt = Get-Date
$sourceCount = [int]$Matches[1]
$referenceCount = [int]$Matches[2]

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
  $ApiKey = $env:T8STAR_API_KEY
}
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
  $ApiKey = Read-Host "Enter T8STAR_API_KEY for https://ai.t8star.org/v1"
}
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
  Write-Error "Missing API key. Pass -ApiKey, set T8STAR_API_KEY, or enter it when prompted."
  exit 1
}

if ([string]::IsNullOrWhiteSpace($SourceDir)) {
  $SourceDir = (Get-Location).Path
}
$sourceDir = $SourceDir
$referenceStart = $sourceCount + 1
if (-not $ReferencePaths -or $ReferencePaths.Count -eq 0) {
  if ([string]::IsNullOrWhiteSpace($ReferenceDir)) {
    $ReferenceDir = Join-Path $sourceDir "颜色"
  }
  foreach ($i in $referenceStart..($sourceCount + $referenceCount)) {
    $ReferencePaths += (Join-Path $ReferenceDir "$i.jpg")
  }
}
$editScript = "$env:USERPROFILE\.codex\skills\zz-gpt-image2-i2i\scripts\edit-image.ps1"

if ($ReferencePaths.Count -ne $referenceCount) {
  Write-Error "Reference path count mismatch. -Count $Count requires $referenceCount reference path(s), but got $($ReferencePaths.Count)."
  exit 1
}

foreach ($referencePath in $ReferencePaths) {
  if (-not (Test-Path -LiteralPath $referencePath)) {
    Write-Error "Reference image not found: $referencePath"
    exit 1
  }
}

function ConvertTo-ColorWord {
  param(
    [double]$Hue,
    [double]$Saturation,
    [double]$Value
  )

  if ($Value -lt 0.18) { return "black" }
  if ($Saturation -lt 0.16) {
    if ($Value -gt 0.82) { return "white" }
    return "gray"
  }
  if ($Hue -lt 15 -or $Hue -ge 345) {
    if ($Value -lt 0.55) { return "brown" }
    return "red"
  }
  if ($Hue -lt 35) {
    if ($Value -lt 0.45) { return "brown" }
    return "orange"
  }
  if ($Hue -lt 55) {
    if ($Value -lt 0.55 -or $Saturation -lt 0.45) { return "brown" }
    return "yellow"
  }
  if ($Hue -lt 150) { return "green" }
  if ($Hue -lt 190) { return "cyan" }
  if ($Hue -lt 255) { return "blue" }
  if ($Hue -lt 285) { return "purple" }
  if ($Hue -lt 330) { return "pink" }
  return "red"
}

function Get-ReferenceColorWord {
  param([Parameter(Mandatory = $true)][string]$Path)

  Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
  $img = [System.Drawing.Image]::FromFile($Path)
  try {
    $bitmap = [System.Drawing.Bitmap]$img
    $stepX = [Math]::Max(1, [Math]::Floor($bitmap.Width / 80))
    $stepY = [Math]::Max(1, [Math]::Floor($bitmap.Height / 80))
    $buckets = @{}

    for ($y = 0; $y -lt $bitmap.Height; $y += $stepY) {
      for ($x = 0; $x -lt $bitmap.Width; $x += $stepX) {
        $pixel = $bitmap.GetPixel($x, $y)
        $r = $pixel.R / 255.0
        $g = $pixel.G / 255.0
        $b = $pixel.B / 255.0
        $max = [Math]::Max($r, [Math]::Max($g, $b))
        $min = [Math]::Min($r, [Math]::Min($g, $b))
        $delta = $max - $min
        if ($max -gt 0.92 -and $delta -lt 0.08) { continue }
        if ($max -lt 0.08) { continue }

        $saturation = if ($max -eq 0) { 0 } else { $delta / $max }
        if ($saturation -lt 0.08 -and $max -gt 0.75) { continue }

        if ($delta -eq 0) {
          $hue = 0
        } elseif ($max -eq $r) {
          $hue = 60 * ((($g - $b) / $delta) % 6)
        } elseif ($max -eq $g) {
          $hue = 60 * ((($b - $r) / $delta) + 2)
        } else {
          $hue = 60 * ((($r - $g) / $delta) + 4)
        }
        if ($hue -lt 0) { $hue += 360 }

        $word = ConvertTo-ColorWord -Hue $hue -Saturation $saturation -Value $max
        $weight = [Math]::Max(0.2, $saturation) * [Math]::Max(0.2, (1.0 - [Math]::Abs($max - 0.55)))
        if (-not $buckets.ContainsKey($word)) { $buckets[$word] = 0.0 }
        $buckets[$word] += $weight
      }
    }

    if ($buckets.Count -eq 0) { return "color" }
    return ($buckets.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
  } finally {
    $img.Dispose()
  }
}

function Get-ImageEditSize {
  param([Parameter(Mandatory = $true)][string]$Path)

  if ($Size -ne "auto") {
    return $Size
  }

  try {
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    $img = [System.Drawing.Image]::FromFile($Path)
    try {
      $w = $img.Width
      $h = $img.Height
    } finally {
      $img.Dispose()
    }

    $w = [Math]::Floor($w / 16) * 16
    $h = [Math]::Floor($h / 16) * 16
    if ($w -lt 16 -or $h -lt 16) {
      return "2048x2048"
    }

    $pixels = $w * $h
    if ($pixels -lt 655360 -or $pixels -gt 8294400) {
      return "2048x2048"
    }
    if (([Math]::Max($w, $h) / [Math]::Min($w, $h)) -gt 3) {
      return "2048x2048"
    }
    if ([Math]::Max($w, $h) -gt 3840) {
      return "2048x2048"
    }

    return "$($w)x$($h)"
  } catch {
    return "2048x2048"
  }
}

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
  $folderName = $ColorName.Trim().ToLowerInvariant()
  if ([string]::IsNullOrWhiteSpace($folderName)) {
    $colorWords = @($ReferencePaths | ForEach-Object { Get-ReferenceColorWord -Path $_ } | Select-Object -Unique)
    $folderName = ($colorWords -join "-").ToLowerInvariant()
  }
  $folderName = ($folderName -replace '[^\w.-]+', '-').Trim('-')
  if ([string]::IsNullOrWhiteSpace($folderName)) { $folderName = "color" }
  if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = (Get-Location).Path
  }
  $OutputDir = Join-Path $OutputRoot $folderName
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
if ([string]::IsNullOrWhiteSpace($TargetFinish)) {
  $TargetFinish = if ([string]::IsNullOrWhiteSpace($ColorName)) { "the reference image finish" } else { "$ColorName wood-grain finish" }
}
$prompt = @"
Use the reference image(s) only as the color and material reference.
Recolor the Adirondack chair product surfaces in the source image to match $TargetFinish.

The source image is the ecommerce listing image that must be edited.
The reference image(s) are only target finish references. Do not copy their layout, camera angle, background, product shape, crop, or composition.

Recolor only the sellable chair surfaces and matching chair accessories such as the attached cup holder or phone slot when they are part of the chair.
Keep the original composition, layout, camera angle, product structure, proportions, lighting, shadows, wood grain, text, icons, dimension lines, people, clothing, props, plants, drinks, background, pool water, grass, house, fireplace, graphic layout, and all non-product elements unchanged.

The target finish must match the reference material, including undertone, highlight behavior, shadow depth, grain contrast, and surface sheen.
Preserve visible wood grain, molded texture, board direction, bevels, seams, screws, labels, hardware, natural lighting, and realistic shadows.
Remove every trace of the original light blue color from product surfaces only, including blue edge highlights, blue reflections, rim light, and anti-aliased borders.
Do not recolor unrelated objects such as text, icons, green labels, clothing, sky, water, grass, flooring, decor, people, hair, drinks, metal screws, or background wood.
Do not redesign, restyle, simplify, regenerate, add, remove, or rearrange any elements.
"@

$jobs = @()
foreach ($i in 1..$sourceCount) {
  while (($jobs | Where-Object { $_.State -eq "Running" }).Count -ge $Parallel) {
    $done = Wait-Job -Job $jobs -Any -Timeout 5
    if ($done) {
      Receive-Job -Job $done
      Remove-Job -Job $done
      $jobs = @($jobs | Where-Object { $_.Id -ne $done.Id })
    }
  }

  $sourcePath = Join-Path $sourceDir "$i.jpg"
  $outputPath = Join-Path $OutputDir "$i.png"
  $taskSize = Get-ImageEditSize -Path $sourcePath
  $jobs += Start-Job -ScriptBlock {
    param($EditScript, $BaseUrl, $Model, $SourcePath, $ReferencePaths, $Prompt, $OutputPath, $Size, $ApiKey)
    try {
      $imagePaths = @($SourcePath) + $ReferencePaths
      & $EditScript `
        -BaseUrl $BaseUrl `
        -Model $Model `
        -ImagePaths $imagePaths `
        -Prompt $Prompt `
        -OutputPath $OutputPath `
        -Size $Size `
        -ApiKey $ApiKey `
        -Async `
        -SkipModelCheck `
        -PollIntervalSec 10 `
        -MaxPollSec 1800
      [pscustomobject]@{ Source = $SourcePath; Output = $OutputPath; Size = $Size; Success = (Test-Path -LiteralPath $OutputPath); Error = "" }
    } catch {
      [pscustomobject]@{ Source = $SourcePath; Output = $OutputPath; Size = $Size; Success = $false; Error = $_.Exception.Message }
    }
  } -ArgumentList $editScript, $BaseUrl, $Model, $sourcePath, $ReferencePaths, $prompt, $outputPath, $taskSize, $ApiKey
}

while ($jobs.Count -gt 0) {
  $done = Wait-Job -Job $jobs -Any
  Receive-Job -Job $done
  Remove-Job -Job $done
  $jobs = @($jobs | Where-Object { $_.Id -ne $done.Id })
}

$finishedAt = Get-Date
$elapsed = $finishedAt - $startedAt
Get-ChildItem -LiteralPath $OutputDir -File | Sort-Object Name | Select-Object Name, Length
Write-Host ("ELAPSED_SECONDS={0:N1}" -f $elapsed.TotalSeconds)
Write-Host ("ELAPSED=" + $elapsed.ToString("hh\:mm\:ss"))
