param(
  [Parameter(Mandatory = $true)]
  [string]$Count,
  [Parameter(Mandatory = $true)]
  [string[]]$ImagePaths,
  [Parameter(Mandatory = $true)]
  [string]$OutputDir,
  [string]$BaseUrl = "https://ai.t8star.org/v1",
  [string]$Model = "gpt-image-2",
  [string]$ApiKey = "",
  [string]$Size = "auto",
  [int]$Parallel = 0,
  [int]$MaxParallel = 10,
  [string]$TargetProduct = "product",
  [string]$TargetFinish = "the reference image finish"
)

$ErrorActionPreference = "Continue"

if ($Count -notmatch '^(\d+)\+(\d+)$') {
  Write-Error "Invalid -Count '$Count'. Expected N+M, for example 8+1."
  exit 1
}

$sourceCount = [int]$Matches[1]
$referenceCount = [int]$Matches[2]
$expectedCount = $sourceCount + $referenceCount
if ($ImagePaths.Count -ne $expectedCount) {
  Write-Error "Image path count mismatch. -Count $Count requires $expectedCount image paths, but got $($ImagePaths.Count)."
  exit 1
}

if ($Parallel -le 0) {
  $Parallel = $sourceCount
}
if ($Parallel -gt $MaxParallel) {
  $Parallel = $MaxParallel
}

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
  $ApiKey = $env:T8STAR_API_KEY
}
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
  $ApiKey = $env:NEWAPI_API_KEY
}
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
  Write-Error "Missing API key. Pass -ApiKey or set T8STAR_API_KEY / NEWAPI_API_KEY."
  exit 1
}

$editScript = "$env:USERPROFILE\.codex\skills\zz-gpt-image2-i2i\scripts\edit-image.ps1"
if (-not (Test-Path -LiteralPath $editScript)) {
  Write-Error "Required edit script not found: $editScript"
  exit 1
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$sourcePaths = @($ImagePaths | Select-Object -First $sourceCount)
$referencePaths = @($ImagePaths | Select-Object -Last $referenceCount)

$prompt = @"
Use the last $referenceCount image(s) only as the color and material reference.
Recolor all $TargetProduct surfaces in the first source image to match $TargetFinish.

The first image is the ecommerce listing image that must be edited.
The remaining image(s) are reference images for the desired product color/material only.
Do not copy the layout, camera angle, background, product shape, crop, or composition from the reference images.

Recolor only the sellable product surfaces and matching companion product surfaces in the source image.
Keep the original composition, layout, camera angle, product structure, proportions, lighting, shadows, texture, text, icons, dimension lines, people, clothing, props, plants, drinks, background, graphic layout, and all non-product elements exactly unchanged.

The final product color must match the reference image(s) as closely as possible, with strong consistency across all edited source images.
No unwanted color cast, no uneven color shift, no leftover original color, no edge contamination, no reflected color residue.

Preserve realistic material texture, grain direction, surface detail, edge highlights, seams, screws, metal hardware, labels, and natural shadow behavior.
Do not redesign, restyle, simplify, regenerate, add, remove, or rearrange any elements.
"@

function Get-ImageEditSize {
  param([string]$Path)

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

$jobs = @()
for ($i = 0; $i -lt $sourcePaths.Count; $i++) {
  while (($jobs | Where-Object { $_.State -eq "Running" }).Count -ge $Parallel) {
    $done = Wait-Job -Job $jobs -Any -Timeout 5
    if ($done) {
      Receive-Job -Job $done
      Remove-Job -Job $done
      $jobs = @($jobs | Where-Object { $_.Id -ne $done.Id })
    }
  }

  $sourcePath = $sourcePaths[$i]
  if (-not (Test-Path -LiteralPath $sourcePath)) {
    Write-Error "Source image not found: $sourcePath"
    continue
  }
  foreach ($referencePath in $referencePaths) {
    if (-not (Test-Path -LiteralPath $referencePath)) {
      Write-Error "Reference image not found: $referencePath"
      continue
    }
  }

  $sourceName = [System.IO.Path]::GetFileNameWithoutExtension($sourcePath)
  $safeName = ($sourceName -replace '[^\w.-]+', '_').Trim('_')
  if ([string]::IsNullOrWhiteSpace($safeName)) {
    $safeName = "{0:D2}" -f ($i + 1)
  }
  $outputPath = Join-Path $OutputDir "$safeName.png"
  $taskSize = Get-ImageEditSize -Path $sourcePath
  $inputPaths = @($sourcePath) + $referencePaths

  $jobs += Start-Job -ScriptBlock {
    param($EditScript, $BaseUrl, $Model, $InputPaths, $Prompt, $OutputPath, $TaskSize, $ApiKey)
    try {
      & $EditScript `
        -BaseUrl $BaseUrl `
        -Model $Model `
        -ImagePaths $InputPaths `
        -Prompt $Prompt `
        -OutputPath $OutputPath `
        -Size $TaskSize `
        -ApiKey $ApiKey `
        -Async `
        -SkipModelCheck `
        -PollIntervalSec 10 `
        -MaxPollSec 1800
      [pscustomobject]@{ Source = $InputPaths[0]; Output = $OutputPath; Size = $TaskSize; Success = (Test-Path -LiteralPath $OutputPath); Error = "" }
    } catch {
      [pscustomobject]@{ Source = $InputPaths[0]; Output = $OutputPath; Size = $TaskSize; Success = $false; Error = $_.Exception.Message }
    }
  } -ArgumentList $editScript, $BaseUrl, $Model, $inputPaths, $prompt, $outputPath, $taskSize, $ApiKey
}

while ($jobs.Count -gt 0) {
  $done = Wait-Job -Job $jobs -Any
  Receive-Job -Job $done
  Remove-Job -Job $done
  $jobs = @($jobs | Where-Object { $_.Id -ne $done.Id })
}

Get-ChildItem -LiteralPath $OutputDir -File | Sort-Object Name | Select-Object Name, Length
