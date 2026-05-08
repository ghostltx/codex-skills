# RunningHub text-to-image helper.
# Submits a task, polls the recommended v2 query API, and downloads the result.

param(
    [Parameter(Mandatory = $true)]
    [string]$Prompt,

    [ValidateSet("1:1", "16:9", "9:16", "4:3", "3:4")]
    [string]$AspectRatio = "1:1",

    [long]$Seed = 0,

    [string]$OutputPath = "",

    [string]$ApiKey = "12b7c9e5908c4daea92a98983306cb6b",

    [string]$WorkflowId = "2047717286877863938",

    [int[]]$PollDelays = @(60, 30, 30, 60, 60, 60, 60, 60, 60),

    [int]$RequestRetries = 3,

    [int]$RetryDelaySeconds = 8
)

$ErrorActionPreference = "Stop"
$BaseUrl = "https://www.runninghub.cn"

function New-DefaultOutputPath {
    $desktop = [Environment]::GetFolderPath("Desktop")
    if ([string]::IsNullOrWhiteSpace($desktop)) {
        $desktop = (Get-Location).Path
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    return (Join-Path $desktop "runninghub_t2i_$timestamp.png")
}

function Ensure-ParentDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)

    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

function Write-Result {
    param(
        [string]$TaskId,
        [string]$Status,
        [string]$OutputPath = "",
        [string]$ImageUrl = ""
    )

    Write-Host "TASK_ID=$TaskId"
    Write-Host "STATUS=$Status"
    if ($OutputPath) { Write-Host "OUTPUT_PATH=$OutputPath" }
    if ($ImageUrl) { Write-Host "IMAGE_URL=$ImageUrl" }
}

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Operation,
        [Parameter(Mandatory = $true)][string]$Label
    )

    for ($attempt = 1; $attempt -le $RequestRetries; $attempt++) {
        try {
            return & $Operation
        } catch {
            if ($attempt -ge $RequestRetries) {
                throw
            }
            Write-Warning "$Label failed on attempt $attempt/$RequestRetries`: $_"
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = New-DefaultOutputPath
}

Ensure-ParentDirectory -Path $OutputPath

if ($Seed -eq 0) {
    $Seed = Get-Random -Minimum 10000000 -Maximum 99999999
}

$jsonHeaders = @{ "Content-Type" = "application/json" }
$queryHeaders = @{
    "Content-Type" = "application/json"
    "Authorization" = "Bearer $ApiKey"
}

Write-Host "RunningHub T2I"
Write-Host "AspectRatio: $AspectRatio"
Write-Host "Seed: $Seed"
Write-Host "OutputPath: $OutputPath"

$createBody = @{
    apiKey = $ApiKey
    workflowId = $WorkflowId
    nodeInfoList = @(
        @{
            nodeId = "2"
            fieldName = "text"
            fieldValue = $Prompt
        },
        @{
            nodeId = "1"
            fieldName = "aspectRatio"
            fieldValue = $AspectRatio
        },
        @{
            nodeId = "1"
            fieldName = "seed"
            fieldValue = $Seed
        }
    )
} | ConvertTo-Json -Depth 10

$createResponse = $null
for ($attempt = 1; $attempt -le $RequestRetries; $attempt++) {
    try {
        $createResponse = Invoke-RestMethod -Uri "$BaseUrl/task/openapi/create" -Method Post -Headers $jsonHeaders -Body $createBody
    } catch {
        if ($attempt -ge $RequestRetries) {
            Write-Error "Create request failed: $_"
            exit 1
        }
        Write-Warning "Create request failed on attempt $attempt/$RequestRetries`: $_"
        Start-Sleep -Seconds $RetryDelaySeconds
        continue
    }

    if ($createResponse.code -eq 0) {
        break
    }

    if ($attempt -lt $RequestRetries -and "$($createResponse.msg)" -match "TASK_QUEUE_MAXED|QUEUE|busy|timeout") {
        Write-Warning "Create task returned $($createResponse.msg) on attempt $attempt/$RequestRetries; retrying."
        Start-Sleep -Seconds $RetryDelaySeconds
        continue
    }

    Write-Error "Create task failed: $($createResponse.msg)"
    exit 1
}

$taskId = $createResponse.data.taskId
Write-Host "TaskId: $taskId"

$elapsed = 0
foreach ($delay in $PollDelays) {
    $elapsed += $delay
    Write-Host "Waiting ${delay}s before query (${elapsed}s elapsed)..."
    Start-Sleep -Seconds $delay

    $queryBody = @{ taskId = $taskId } | ConvertTo-Json

    try {
        $queryResponse = Invoke-RestMethod -Uri "$BaseUrl/openapi/v2/query" -Method Post -Headers $queryHeaders -Body $queryBody
    } catch {
        Write-Warning "Query failed at ${elapsed}s: $_"
        continue
    }

    $status = $queryResponse.status
    Write-Host "Status: $status"

    if ($status -eq "FAILED") {
        Write-Error "Task failed: $($queryResponse.failedReason | ConvertTo-Json -Depth 5 -Compress)"
        Write-Result -TaskId $taskId -Status "FAILED"
        exit 1
    }

    if ($status -ne "SUCCESS") {
        continue
    }

    $imageUrl = $null
    if ($queryResponse.results -and $queryResponse.results.Count -gt 0) {
        $imageUrl = $queryResponse.results[0].url
    }

    if ([string]::IsNullOrWhiteSpace($imageUrl)) {
        Write-Error "Task succeeded but no image URL was returned."
        Write-Result -TaskId $taskId -Status "SUCCESS_NO_URL"
        exit 1
    }

    try {
        Invoke-WithRetry -Label "Download result" -Operation {
            Invoke-WebRequest -Uri $imageUrl -OutFile $OutputPath -UseBasicParsing
        } | Out-Null
    } catch {
        Write-Error "Download failed: $_"
        Write-Result -TaskId $taskId -Status "SUCCESS_DOWNLOAD_FAILED" -ImageUrl $imageUrl
        exit 1
    }

    $file = Get-Item -LiteralPath $OutputPath
    $sizeMb = [math]::Round(($file.Length / 1MB), 2)

    Write-Host "Done: $OutputPath ($sizeMb MB)"
    Write-Result -TaskId $taskId -Status "SUCCESS" -OutputPath $OutputPath -ImageUrl $imageUrl
    exit 0
}

Write-Warning "Task is still running after $elapsed seconds."
Write-Result -TaskId $taskId -Status "TIMEOUT"
exit 2
