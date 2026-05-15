param(
  [string]$BaseUrl = "https://ai.t8star.cn/v1",
  [string]$Model = "gpt-image-2",
  [string]$ImagePath = "",
  [string[]]$ImagePaths = @(),
  [Parameter(Mandatory = $true)]
  [string]$Prompt,
  [string]$MaskPath = "",
  [string]$Size = "2048x2048",
  [int]$TimeoutSec = 180,
  [switch]$Async,
  [switch]$Sync,
  [switch]$SkipModelCheck,
  [int]$PollIntervalSec = 10,
  [int]$MaxPollSec = 1200,
  [int]$MaxPollErrors = 12,
  [string]$OutputPath = "",
  [string]$ApiKey = "sk-8eqMmG42duTRthbDR3Afa14k09pkvGVhTD5akQog5YrmgqCQ,sk-UqNU5XYCnahW54wzV75KMPH2FSiSivSK0iGp7eu280xWgrlw,sk-zhjsmJHyA9ZUEzqV0mHswsQqZfyhyocBMJCRNd3SbatxsUMa,sk-WwEfMmHzVW9cd5w38euoUB6G0rJ0O2aTFfxbpBGXDWESC2d2"
)

$ErrorActionPreference = "Stop"

function Import-DotEnv {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return
  }

  Get-Content -LiteralPath $Path | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith("#") -or $line -notmatch "^\s*([^=]+?)\s*=\s*(.*)\s*$") {
      return
    }

    $name = $Matches[1].Trim()
    $value = $Matches[2].Trim()
    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
      $value = $value.Substring(1, $value.Length - 2)
    }

    if ($name) {
      Set-Item -Path "Env:$name" -Value $value
    }
  }
}

$skillRoot = Split-Path -Parent $PSScriptRoot
Import-DotEnv -Path (Join-Path $skillRoot ".env")

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
  $ApiKey = $env:T8STAR_API_KEY
}

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
  Write-Error "Missing API key. Pass -ApiKey or set `$env:T8STAR_API_KEY."
}

$apiKeys = @(
  $ApiKey -split "," |
    ForEach-Object { $_.Trim() } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    Select-Object -Unique
)

if (-not $apiKeys -or $apiKeys.Count -eq 0) {
  Write-Error "Missing API key. Pass -ApiKey or set `$env:T8STAR_API_KEY."
}

function Get-AuthHeaders {
  param([Parameter(Mandatory = $true)][int]$KeyIndex)

  return @{
    Authorization = "Bearer $($apiKeys[$KeyIndex])"
  }
}

function Get-DefaultOutputPath {
  $desktop = [Environment]::GetFolderPath("Desktop")
  if ([string]::IsNullOrWhiteSpace($desktop)) {
    $desktop = (Get-Location).Path
  }

  $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
  return (Join-Path $desktop "zz_gpt_image2_i2i_$timestamp.png")
}

function Resolve-OutputPath {
  param([string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path)) {
    $Path = Get-DefaultOutputPath
  }

  $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
  $outputDir = Split-Path -Parent $resolved
  if ($outputDir -and -not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
  }

  return $resolved
}

function Test-ImageSize {
  param([string]$Value)

  if ($Value -eq "auto") {
    return
  }

  if ($Value -notmatch '^(\d+)x(\d+)$') {
    Write-Error "Invalid size '$Value'. Expected format like 2048x2048 or auto."
  }

  $width = [int]$Matches[1]
  $height = [int]$Matches[2]
  $longEdge = [Math]::Max($width, $height)
  $shortEdge = [Math]::Min($width, $height)
  $pixels = $width * $height

  if ($longEdge -gt 3840) {
    Write-Error "Invalid size '$Value'. The longest edge must be less than or equal to 3840."
  }
  if (($width % 16 -ne 0) -or ($height % 16 -ne 0)) {
    Write-Error "Invalid size '$Value'. Width and height must both be divisible by 16."
  }
  if (($longEdge / $shortEdge) -gt 3) {
    Write-Error "Invalid size '$Value'. Long-edge to short-edge ratio must be less than or equal to 3:1."
  }
  if (($pixels -lt 655360) -or ($pixels -gt 8294400)) {
    Write-Error "Invalid size '$Value'. Total pixels must be from 655360 through 8294400."
  }
}

function Get-InputImagePaths {
  $paths = @()
  if (-not [string]::IsNullOrWhiteSpace($ImagePath)) {
    $paths += $ImagePath
  }
  if ($ImagePaths -and $ImagePaths.Count -gt 0) {
    $paths += $ImagePaths
  }

  $paths = $paths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
  if (-not $paths -or $paths.Count -eq 0) {
    Write-Error "Provide -ImagePath or -ImagePaths."
  }

  foreach ($path in $paths) {
    if (-not (Test-Path -LiteralPath $path)) {
      Write-Error "Input image not found: $path"
    }
  }

  return $paths
}

function New-TempImageCopies {
  param([Parameter(Mandatory = $true)][string[]]$Paths)

  $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("zz_gpt_image2_i2i_" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $tempRoot | Out-Null

  $copies = @()
  for ($i = 0; $i -lt $Paths.Count; $i++) {
    $sourcePath = $Paths[$i]
    $extension = [IO.Path]::GetExtension($sourcePath)
    if ([string]::IsNullOrWhiteSpace($extension)) {
      $extension = ".png"
    }

    $copyPath = Join-Path $tempRoot ("input_{0:D2}{1}" -f ($i + 1), $extension)
    Copy-Item -LiteralPath $sourcePath -Destination $copyPath -Force
    $copies += $copyPath
  }

  return @{
    Root = $tempRoot
    Paths = $copies
  }
}

function Save-ImageResult {
  param(
    [Parameter(Mandatory = $true)]$Result,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $image = $Result.data | Select-Object -First 1
  if ($image.b64_json) {
    [IO.File]::WriteAllBytes($Path, [Convert]::FromBase64String($image.b64_json))
    Write-Host "OK: image saved to $Path"
  } elseif ($image.url) {
    Invoke-WebRequest -Uri $image.url -OutFile $Path -UseBasicParsing -TimeoutSec $TimeoutSec
    Write-Host "OK: image URL returned and downloaded:"
    Write-Host $image.url
    Write-Host "OK: image saved to $Path"
  } else {
    Write-Host "Edit response:"
    $Result | ConvertTo-Json -Depth 12
  }
}

$useAsync = -not $Sync
if ($Async) {
  $useAsync = $true
}

$activeKeyIndex = 0
if (-not $SkipModelCheck) {
  Write-Host "Testing API connectivity: $BaseUrl/models"
  $modelCheckOk = $false
  for ($keyAttempt = 0; $keyAttempt -lt $apiKeys.Count; $keyAttempt++) {
    $headers = Get-AuthHeaders -KeyIndex $keyAttempt
    try {
      $models = Invoke-RestMethod -Method Get -Uri "$BaseUrl/models" -Headers $headers -TimeoutSec 30

      $target = $models.data | Where-Object { $_.id -eq $Model } | Select-Object -First 1
      if (-not $target) {
        Write-Error "Connected, but model '$Model' was not found in /models."
      }

      $activeKeyIndex = $keyAttempt
      $modelCheckOk = $true
      Write-Host "OK: connected and authenticated."
      Write-Host "OK: model found: $($target.id)"
      Write-Host "KEY_POOL_COUNT=$($apiKeys.Count)"
      Write-Host "ACTIVE_KEY_INDEX=$($activeKeyIndex + 1)"
      break
    } catch {
      Write-Host "MODEL_CHECK_KEY_FAILED_INDEX=$($keyAttempt + 1) ERROR=$($_.Exception.Message)"
    }
  }

  if (-not $modelCheckOk) {
    Write-Error "All configured API keys failed /models check."
  }
} else {
  Write-Host "Skipping /models check. Using model: $Model"
  Write-Host "KEY_POOL_COUNT=$($apiKeys.Count)"
}

Test-ImageSize -Value $Size
$inputPaths = Get-InputImagePaths
$tempInputs = New-TempImageCopies -Paths $inputPaths
$inputPaths = $tempInputs.Paths
$resolvedOutputPath = Resolve-OutputPath -Path $OutputPath

$editUri = "$BaseUrl/images/edits"
if ($useAsync) {
  $separator = if ($editUri.Contains("?")) { "&" } else { "?" }
  $editUri = "$editUri${separator}async=true"
  Write-Host "Async edit mode enabled."
} else {
  Write-Host "Sync edit mode enabled."
}

$form = @{
  model = $Model
  prompt = $Prompt
  size = $Size
}

if (-not [string]::IsNullOrWhiteSpace($MaskPath)) {
  if (-not (Test-Path -LiteralPath $MaskPath)) {
    Write-Error "Mask image not found: $MaskPath"
  }
  $form.mask = Get-Item -LiteralPath $MaskPath
}

if ($inputPaths.Count -eq 1) {
  $form.image = Get-Item -LiteralPath $inputPaths[0]
} else {
  $form.image = @($inputPaths | ForEach-Object { Get-Item -LiteralPath $_ })
}

Write-Host "Submitting image edit with $($inputPaths.Count) input image(s)."
$result = $null
$lastFailure = ""
$completed = $false
for ($keyAttempt = 0; $keyAttempt -lt $apiKeys.Count; $keyAttempt++) {
  $keyIndex = ($activeKeyIndex + $keyAttempt) % $apiKeys.Count
  $headers = Get-AuthHeaders -KeyIndex $keyIndex
  Write-Host "USING_KEY_INDEX=$($keyIndex + 1)/$($apiKeys.Count)"

  try {
    $result = Invoke-RestMethod `
      -Method Post `
      -Uri $editUri `
      -Headers $headers `
      -Form $form `
      -TimeoutSec $TimeoutSec

    if ($useAsync) {
      $taskId = $result.task_id
      if (-not $taskId -and $result.data.task_id) {
        $taskId = $result.data.task_id
      }
      if (-not $taskId) {
        Write-Host "Async submit response:"
        $result | ConvertTo-Json -Depth 12
        throw "Async edit request did not return task_id."
      }

      Write-Host "OK: async edit task submitted: $taskId"
      $deadline = (Get-Date).AddSeconds($MaxPollSec)
      $pollErrors = 0
      $status = ""
      do {
        Start-Sleep -Seconds $PollIntervalSec
        try {
          $task = Invoke-RestMethod `
            -Method Get `
            -Uri "$BaseUrl/images/tasks/$taskId" `
            -Headers ($headers + @{ "Content-Type" = "application/json" }) `
            -TimeoutSec $TimeoutSec
        } catch {
          $pollErrors += 1
          Write-Host "Task poll error $pollErrors/$MaxPollErrors`: $($_.Exception.Message)"
          if ($pollErrors -ge $MaxPollErrors) {
            throw
          }
          continue
        }

        $taskData = if ($task.data) { $task.data } else { $task }
        $status = $taskData.status
        $progress = $taskData.progress
        if ($progress) {
          Write-Host "Task status: $status ($progress)"
        } else {
          Write-Host "Task status: $status"
        }

        if ($status -eq "FAILURE") {
          $lastFailure = if ($taskData.fail_reason) { $taskData.fail_reason } elseif ($taskData.failedReason) { ($taskData.failedReason | ConvertTo-Json -Depth 5 -Compress) } else { "Async image edit failed." }
          Write-Host "TASK_FAILED_KEY_INDEX=$($keyIndex + 1) REASON=$lastFailure"
          throw "Async image edit failed."
        }

        if ($status -eq "SUCCESS") {
          $result = $taskData.data
          $completed = $true
          break
        }
      } while ((Get-Date) -lt $deadline)

      if (-not $completed) {
        throw "Async image edit did not finish within $MaxPollSec seconds."
      }
    } else {
      $completed = $true
    }

    if ($completed) {
      break
    }
  } catch {
    $lastFailure = $_.Exception.Message
    Write-Host "KEY_RETRY_FAILED_INDEX=$($keyIndex + 1) ERROR=$lastFailure"
    if ($keyAttempt -lt ($apiKeys.Count - 1)) {
      Write-Host "SWITCHING_TO_NEXT_KEY"
    }
  }
}

if (-not $completed) {
  Write-Error "Image edit failed after trying $($apiKeys.Count) API key(s). Last error: $lastFailure"
}

Save-ImageResult -Result $result -Path $resolvedOutputPath

if ($tempInputs.Root -and (Test-Path -LiteralPath $tempInputs.Root)) {
  Get-ChildItem -LiteralPath $tempInputs.Root -File | ForEach-Object {
    Remove-Item -LiteralPath $_.FullName -Force
  }
  Remove-Item -LiteralPath $tempInputs.Root -Force
}
