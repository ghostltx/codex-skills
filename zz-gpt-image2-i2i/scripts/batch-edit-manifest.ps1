param(
  [string]$BaseUrl = "https://ai.t8star.cn/v1",
  [string]$Model = "gpt-image-2",
  [string]$ImagePath = "",
  [string[]]$ImagePaths = @(),
  [Parameter(Mandatory = $true)]
  [string]$PromptsPath,
  [Parameter(Mandatory = $true)]
  [string]$OutputDir,
  [string]$Size = "2048x2048",
  [int]$TimeoutSec = 180,
  [int]$PollIntervalSec = 10,
  [int]$MaxPollSec = 1800,
  [int]$MaxRetryRounds = 3,
  [string]$FilePrefix = "zz_gpt_image2_i2i_batch",
  [switch]$SkipModelCheck,
  [string]$ApiKey = "sk-8eqMmG42duTRthbDR3Afa14k09pkvGVhTD5akQog5YrmgqCQ"
)

$ErrorActionPreference = "Stop"

function Import-DotEnv {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return }
  Get-Content -LiteralPath $Path | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith("#") -or $line -notmatch "^\s*([^=]+?)\s*=\s*(.*)\s*$") { return }
    $name = $Matches[1].Trim()
    $value = $Matches[2].Trim()
    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
      $value = $value.Substring(1, $value.Length - 2)
    }
    if ($name) { Set-Item -Path "Env:$name" -Value $value }
  }
}

$skillRoot = Split-Path -Parent $PSScriptRoot
Import-DotEnv -Path (Join-Path $skillRoot ".env")
if ([string]::IsNullOrWhiteSpace($ApiKey)) { $ApiKey = $env:T8STAR_API_KEY }
if ([string]::IsNullOrWhiteSpace($ApiKey)) { Write-Error "Missing API key. Pass -ApiKey or set `$env:T8STAR_API_KEY." }

function Test-ImageSize {
  param([string]$Value)
  if ($Value -eq "auto") { return }
  if ($Value -notmatch '^(\d+)x(\d+)$') { Write-Error "Invalid size '$Value'. Expected format like 1632x2048 or auto." }
  $width = [int]$Matches[1]
  $height = [int]$Matches[2]
  $longEdge = [Math]::Max($width, $height)
  $shortEdge = [Math]::Min($width, $height)
  $pixels = $width * $height
  if ($longEdge -gt 3840) { Write-Error "Invalid size '$Value'. The longest edge must be less than or equal to 3840." }
  if (($width % 16 -ne 0) -or ($height % 16 -ne 0)) { Write-Error "Invalid size '$Value'. Width and height must both be divisible by 16." }
  if (($longEdge / $shortEdge) -gt 3) { Write-Error "Invalid size '$Value'. Long-edge to short-edge ratio must be less than or equal to 3:1." }
  if (($pixels -lt 655360) -or ($pixels -gt 8294400)) { Write-Error "Invalid size '$Value'. Total pixels must be from 655360 through 8294400." }
}

function Get-InputImagePaths {
  $paths = @()
  if (-not [string]::IsNullOrWhiteSpace($ImagePath)) { $paths += $ImagePath }
  if ($ImagePaths -and $ImagePaths.Count -gt 0) { $paths += $ImagePaths }
  $paths = $paths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
  if (-not $paths -or $paths.Count -eq 0) { Write-Error "Provide -ImagePath or -ImagePaths." }
  foreach ($path in $paths) {
    if (-not (Test-Path -LiteralPath $path)) { Write-Error "Input image not found: $path" }
  }
  return $paths
}

function New-TempImageCopies {
  param([Parameter(Mandatory = $true)][string[]]$Paths)
  $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("zz_gpt_image2_i2i_batch_" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $tempRoot | Out-Null
  $copies = @()
  for ($i = 0; $i -lt $Paths.Count; $i++) {
    $extension = [IO.Path]::GetExtension($Paths[$i])
    if ([string]::IsNullOrWhiteSpace($extension)) { $extension = ".png" }
    $copyPath = Join-Path $tempRoot ("input_{0:D2}{1}" -f ($i + 1), $extension)
    Copy-Item -LiteralPath $Paths[$i] -Destination $copyPath -Force
    $copies += $copyPath
  }
  return @{ Root = $tempRoot; Paths = $copies }
}

function Remove-TempCopies {
  param($Temp)
  if ($Temp.Root -and (Test-Path -LiteralPath $Temp.Root)) {
    Get-ChildItem -LiteralPath $Temp.Root -File | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
    Remove-Item -LiteralPath $Temp.Root -Force
  }
}

function Save-TaskResult {
  param(
    [Parameter(Mandatory = $true)]$TaskData,
    [Parameter(Mandatory = $true)][string]$OutputPath
  )
  $result = $TaskData.data
  $image = $result.data | Select-Object -First 1
  if ($image.b64_json) {
    [IO.File]::WriteAllBytes($OutputPath, [Convert]::FromBase64String($image.b64_json))
    return $true
  }
  if ($image.url) {
    Invoke-WebRequest -Uri $image.url -OutFile $OutputPath -UseBasicParsing -TimeoutSec $TimeoutSec
    return $true
  }
  return $false
}

function Read-PromptItems {
  if (-not (Test-Path -LiteralPath $PromptsPath)) { Write-Error "Prompts file not found: $PromptsPath" }
  $items = Get-Content -LiteralPath $PromptsPath -Raw | ConvertFrom-Json
  if ($null -eq $items) { Write-Error "Prompts file is empty or invalid JSON." }
  if ($items -isnot [System.Array]) { $items = @($items) }
  $normalized = @()
  for ($i = 0; $i -lt $items.Count; $i++) {
    $item = $items[$i]
    if ($item -is [string]) {
      $normalized += [pscustomobject]@{ Name = ""; Prompt = $item }
    } else {
      $prompt = [string]$item.prompt
      if ([string]::IsNullOrWhiteSpace($prompt)) { Write-Error "Prompt item $($i + 1) is missing 'prompt'." }
      $normalized += [pscustomobject]@{ Name = [string]$item.name; Prompt = $prompt }
    }
  }
  return $normalized
}

function Submit-ManifestItem {
  param(
    [Parameter(Mandatory = $true)]$Item,
    [Parameter(Mandatory = $true)][string[]]$InputPaths,
    [Parameter(Mandatory = $true)]$Headers
  )
  $temp = New-TempImageCopies -Paths $InputPaths
  try {
    $form = @{
      model = $Model
      prompt = $Item.Prompt
      size = $Size
    }
    if ($temp.Paths.Count -eq 1) {
      $form.image = Get-Item -LiteralPath $temp.Paths[0]
    } else {
      $form.image = @($temp.Paths | ForEach-Object { Get-Item -LiteralPath $_ })
    }
    $submit = Invoke-RestMethod -Method Post -Uri "$BaseUrl/images/edits?async=true" -Headers $Headers -Form $form -TimeoutSec $TimeoutSec
    $taskId = $submit.task_id
    if (-not $taskId -and $submit.data.task_id) { $taskId = $submit.data.task_id }
    if (-not $taskId) { Write-Error "Async edit request did not return task_id." }
    return $taskId
  } finally {
    Remove-TempCopies -Temp $temp
  }
}

Test-ImageSize -Value $Size
$inputPaths = Get-InputImagePaths
$promptItems = Read-PromptItems
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$headers = @{ Authorization = "Bearer $ApiKey" }
if (-not $SkipModelCheck) {
  Write-Host "Testing API connectivity: $BaseUrl/models"
  $models = Invoke-RestMethod -Method Get -Uri "$BaseUrl/models" -Headers $headers -TimeoutSec 30
  $target = $models.data | Where-Object { $_.id -eq $Model } | Select-Object -First 1
  if (-not $target) { Write-Error "Connected, but model '$Model' was not found in /models." }
  Write-Host "OK: connected and authenticated."
  Write-Host "OK: model found: $($target.id)"
} else {
  Write-Host "Skipping /models check. Using model: $Model"
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$manifestPath = Join-Path $OutputDir ("manifest_$stamp.json")
$manifest = @()
for ($i = 0; $i -lt $promptItems.Count; $i++) {
  $index = $i + 1
  $name = $promptItems[$i].Name
  if ([string]::IsNullOrWhiteSpace($name)) { $name = "{0:D2}" -f $index }
  $safeName = ($name -replace '[^\w.-]+', '_').Trim('_')
  if ([string]::IsNullOrWhiteSpace($safeName)) { $safeName = "{0:D2}" -f $index }
  $outputPath = Join-Path $OutputDir ("{0}_{1}_{2}.png" -f $FilePrefix, $stamp, $safeName)
  $manifest += [pscustomobject]@{
    Index = $index
    Name = $name
    Prompt = $promptItems[$i].Prompt
    TaskId = ""
    OutputPath = $outputPath
    Status = "PENDING_SUBMIT"
    Saved = $false
    Failure = ""
    Attempts = 0
  }
}

Write-Host "TASK_DASHBOARD=https://ai.t8star.org/task"
Write-Host "OUTPUT_DIR=$OutputDir"
Write-Host "MANIFEST=$manifestPath"
Write-Host "SIZE=$Size"

for ($round = 0; $round -le $MaxRetryRounds; $round++) {
  $toSubmit = $manifest | Where-Object { -not $_.Saved -and ($_.Status -in @("PENDING_SUBMIT", "FAILURE", "SUBMIT_FAILED", "NO_IMAGE")) }
  if ($toSubmit.Count -eq 0) { break }
  if ($round -gt 0) { Write-Host "RETRY_ROUND=$round COUNT=$($toSubmit.Count)" }
  foreach ($item in $toSubmit) {
    $item.Attempts += 1
    $item.Status = "SUBMITTING"
    $item.Failure = ""
    try {
      $item.TaskId = Submit-ManifestItem -Item $item -InputPaths $inputPaths -Headers $headers
      $item.Status = "SUBMITTED"
      Write-Host ("SUBMITTED_INDEX={0:D2} TASK_ID={1}" -f $item.Index, $item.TaskId)
    } catch {
      $item.Status = "SUBMIT_FAILED"
      $item.Failure = $_.Exception.Message
      Write-Host ("SUBMIT_FAILED_INDEX={0:D2} ERROR={1}" -f $item.Index, $item.Failure)
    }
  }
  $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

  $deadline = (Get-Date).AddSeconds($MaxPollSec)
  do {
    $pending = $manifest | Where-Object { $_.TaskId -and -not $_.Saved -and $_.Status -notin @("FAILURE", "SUBMIT_FAILED", "NO_IMAGE", "SUCCESS") }
    if ($pending.Count -eq 0) { break }
    foreach ($item in $pending) {
      try {
        $task = Invoke-RestMethod -Method Get -Uri "$BaseUrl/images/tasks/$($item.TaskId)" -Headers $headers -TimeoutSec $TimeoutSec
        $taskData = if ($task.data) { $task.data } else { $task }
        $item.Status = $taskData.status
        if ($taskData.status -eq "SUCCESS") {
          if (Save-TaskResult -TaskData $taskData -OutputPath $item.OutputPath) {
            $item.Saved = $true
            Write-Host ("SAVED_INDEX={0:D2} PATH={1}" -f $item.Index, $item.OutputPath)
          } else {
            $item.Status = "NO_IMAGE"
            $item.Failure = "No image URL or b64_json in task result."
            Write-Host ("NO_IMAGE_INDEX={0:D2}" -f $item.Index)
          }
        } elseif ($taskData.status -eq "FAILURE") {
          $item.Failure = if ($taskData.fail_reason) { $taskData.fail_reason } elseif ($taskData.failedReason) { ($taskData.failedReason | ConvertTo-Json -Depth 5 -Compress) } else { "Task failed." }
          Write-Host ("FAILED_INDEX={0:D2} REASON={1}" -f $item.Index, $item.Failure)
        }
      } catch {
        Write-Host ("POLL_ERROR_INDEX={0:D2} ERROR={1}" -f $item.Index, $_.Exception.Message)
      }
    }
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    $savedCount = ($manifest | Where-Object Saved).Count
    $failedCount = ($manifest | Where-Object { $_.Status -in @("FAILURE", "SUBMIT_FAILED", "NO_IMAGE") }).Count
    Write-Host "POLL_SUMMARY_SAVED=$savedCount FAILED=$failedCount PENDING=$($pending.Count)"
    Start-Sleep -Seconds $PollIntervalSec
  } while ((Get-Date) -lt $deadline)
}

$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
$finalFiles = Get-ChildItem -LiteralPath $OutputDir -File -Filter ("{0}_{1}_*.png" -f $FilePrefix, $stamp) | Sort-Object Name
Write-Host "SUMMARY_REQUESTED=$($manifest.Count)"
Write-Host "SUMMARY_FILES=$($finalFiles.Count)"
$missing = $manifest | Where-Object { -not $_.Saved }
Write-Host "SUMMARY_MISSING=$($missing.Count)"
if ($missing.Count -gt 0) {
  $missing | Select-Object Index, Name, Status, Attempts, Failure | Format-Table -AutoSize
}
$finalFiles | Select-Object Name, Length, FullName
