# Query a RunningHub task through /openapi/v2/query.

param(
    [Parameter(Mandatory = $true)]
    [string]$TaskId,

    [switch]$Download,

    [string]$OutputPath = "",

    [string]$ApiKey = "12b7c9e5908c4daea92a98983306cb6b"
)

$ErrorActionPreference = "Stop"
$BaseUrl = "https://www.runninghub.cn"

function New-DefaultOutputPath {
    param([Parameter(Mandatory = $true)][string]$TaskId)

    $desktop = [Environment]::GetFolderPath("Desktop")
    if ([string]::IsNullOrWhiteSpace($desktop)) {
        $desktop = (Get-Location).Path
    }

    return (Join-Path $desktop "runninghub_task_$TaskId.png")
}

function Ensure-ParentDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)

    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

$headers = @{
    "Content-Type" = "application/json"
    "Authorization" = "Bearer $ApiKey"
}

$body = @{ taskId = $TaskId } | ConvertTo-Json
$response = Invoke-RestMethod -Uri "$BaseUrl/openapi/v2/query" -Method Post -Headers $headers -Body $body

$status = $response.status
$imageUrl = $null
if ($response.results -and $response.results.Count -gt 0) {
    $imageUrl = $response.results[0].url
}

Write-Host "TASK_ID=$TaskId"
Write-Host "STATUS=$status"
if ($imageUrl) { Write-Host "IMAGE_URL=$imageUrl" }

if ($status -eq "FAILED") {
    Write-Error "Task failed: $($response.failedReason | ConvertTo-Json -Depth 5 -Compress)"
    exit 1
}

if ($Download) {
    if ($status -ne "SUCCESS" -or [string]::IsNullOrWhiteSpace($imageUrl)) {
        Write-Error "No downloadable image is available yet."
        exit 2
    }

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = New-DefaultOutputPath -TaskId $TaskId
    }

    Ensure-ParentDirectory -Path $OutputPath
    Invoke-WebRequest -Uri $imageUrl -OutFile $OutputPath -UseBasicParsing
    Write-Host "OUTPUT_PATH=$OutputPath"
}
