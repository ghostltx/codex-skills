param(
  [string]$BaseUrl = "https://ai.t8star.cn/v1",
  [string]$Model = "gpt-image-2",
  [switch]$Generate,
  [string]$Prompt = "A simple red apple on a white background",
  [string]$Size = "1024x1024",
  [int]$TimeoutSec = 180,
  [switch]$Async,
  [switch]$SkipModelCheck,
  [int]$PollIntervalSec = 10,
  [int]$MaxPollSec = 900,
  [int]$MaxPollErrors = 12,
  [string]$OutputPath = ".\t8star-test-image.png"
)

$ErrorActionPreference = "Stop"

if (-not $env:T8STAR_API_KEY) {
  Write-Error "Missing T8STAR_API_KEY. Example: `$env:T8STAR_API_KEY='sk-...'; .\scripts\test-t8star.ps1"
}

function Test-ImageSize {
  param([string]$Value)

  if ($Value -notmatch '^(\d+)x(\d+)$') {
    Write-Error "Invalid size '$Value'. Expected format like 1024x1024."
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

$headers = @{
  Authorization = "Bearer $env:T8STAR_API_KEY"
}

if (-not $SkipModelCheck) {
  Write-Host "Testing API connectivity: $BaseUrl/models"
  $models = Invoke-RestMethod -Method Get -Uri "$BaseUrl/models" -Headers $headers -TimeoutSec 30

  $target = $models.data | Where-Object { $_.id -eq $Model } | Select-Object -First 1
  if (-not $target) {
    Write-Error "Connected, but model '$Model' was not found in /models."
  }

  Write-Host "OK: connected and authenticated."
  Write-Host "OK: model found: $($target.id)"
  Write-Host "Endpoint types: $($target.supported_endpoint_types -join ', ')"
} else {
  Write-Host "Skipping /models check. Using model: $Model"
}

if (-not $Generate) {
  Write-Host "Skipped image generation. Add -Generate to test /images/generations."
  exit 0
}

Write-Host "Testing image generation with model: $Model"
Test-ImageSize -Value $Size

$body = @{
  model = $Model
  prompt = $Prompt
  size = $Size
  n = 1
} | ConvertTo-Json -Depth 5

$generationUri = "$BaseUrl/images/generations"
if ($Async) {
  $separator = if ($generationUri.Contains("?")) { "&" } else { "?" }
  $generationUri = "$generationUri${separator}async=true"
  Write-Host "Async mode enabled."
}

$result = Invoke-RestMethod `
  -Method Post `
  -Uri $generationUri `
  -Headers ($headers + @{ "Content-Type" = "application/json" }) `
  -Body $body `
  -TimeoutSec $TimeoutSec

if ($Async) {
  $taskId = $result.task_id
  if (-not $taskId -and $result.data.task_id) {
    $taskId = $result.data.task_id
  }
  if (-not $taskId) {
    Write-Host "Async submit response:"
    $result | ConvertTo-Json -Depth 10
    Write-Error "Async request did not return task_id."
  }

  Write-Host "OK: async task submitted: $taskId"
  $deadline = (Get-Date).AddSeconds($MaxPollSec)
  $pollErrors = 0
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
      $task | ConvertTo-Json -Depth 12
      Write-Error "Async image generation failed."
    }

    if ($status -eq "SUCCESS") {
      $result = $taskData.data
      break
    }
  } while ((Get-Date) -lt $deadline)

  if ($status -ne "SUCCESS") {
    Write-Error "Async image generation did not finish within $MaxPollSec seconds."
  }
}

$image = $result.data | Select-Object -First 1
if ($image.b64_json) {
  $resolvedOutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
  $outputDir = Split-Path -Parent $resolvedOutputPath
  if ($outputDir -and -not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
  }
  [IO.File]::WriteAllBytes($resolvedOutputPath, [Convert]::FromBase64String($image.b64_json))
  Write-Host "OK: image saved to $resolvedOutputPath"
} elseif ($image.url) {
  Write-Host "OK: image URL returned:"
  Write-Host $image.url
} else {
  Write-Host "Generation response:"
  $result | ConvertTo-Json -Depth 10
}
