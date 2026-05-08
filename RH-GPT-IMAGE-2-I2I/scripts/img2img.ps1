# RunningHub image-to-image helper.
# Uploads 1-10 local images with multipart/form-data, creates an I2I task,
# polls /openapi/v2/query, and downloads the result to the desktop by default.

param(
    [string]$ImagePath = "",

    [string[]]$ImagePaths = @(),

    [Parameter(Mandatory = $true)]
    [string]$Prompt,

    [string]$OutputPath = "",

    [string]$ApiKey = "12b7c9e5908c4daea92a98983306cb6b",

    [string]$WorkflowId = "2047956784060567554",

    [string]$AspectRatio = "4:5",

    [string]$Quality = "high",

    [string]$Resolution = "2k",

    [int[]]$PollDelays = @(60, 15, 15, 30, 30),

    [switch]$DisableTempCopies
)

$ErrorActionPreference = "Stop"
$BaseUrl = "https://www.runninghub.cn"

function New-DefaultOutputPath {
    $desktop = [Environment]::GetFolderPath("Desktop")
    if ([string]::IsNullOrWhiteSpace($desktop)) {
        $desktop = (Get-Location).Path
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    return (Join-Path $desktop "runninghub_i2i_$timestamp.png")
}

function Ensure-ParentDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)

    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

function New-TempImageCopies {
    param([Parameter(Mandatory = $true)][string[]]$Paths)

    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("rh_i2i_" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    $copies = @()
    for ($i = 0; $i -lt $Paths.Count; $i++) {
        $sourcePath = $Paths[$i]
        $extension = [IO.Path]::GetExtension($sourcePath)
        $copyPath = Join-Path $tempRoot ("input_{0:D2}{1}" -f ($i + 1), $extension)
        Copy-Item -LiteralPath $sourcePath -Destination $copyPath -Force
        $copies += $copyPath
    }

    return @{
        Root = $tempRoot
        Paths = $copies
    }
}

function Remove-TempImageCopies {
    param($TempCopyInfo)

    if (-not $TempCopyInfo) {
        return
    }

    foreach ($path in $TempCopyInfo.Paths) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }

    if (Test-Path -LiteralPath $TempCopyInfo.Root) {
        Remove-Item -LiteralPath $TempCopyInfo.Root -Force
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

$allImagePaths = @()
if ($ImagePaths -and $ImagePaths.Count -gt 0) {
    $allImagePaths += $ImagePaths
} elseif (-not [string]::IsNullOrWhiteSpace($ImagePath)) {
    $allImagePaths += $ImagePath
}

if ($allImagePaths.Count -lt 1 -or $allImagePaths.Count -gt 10) {
    Write-Error "Provide 1-10 image paths using -ImagePaths, or one image using -ImagePath."
    exit 1
}

$supported = @(".png", ".jpg", ".jpeg", ".webp")
foreach ($path in $allImagePaths) {
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Error "Image file does not exist: $path"
        exit 1
    }

    $imageExt = [IO.Path]::GetExtension($path).ToLowerInvariant()
    if ($imageExt -notin $supported) {
        Write-Error "Unsupported image format: $imageExt. Supported: $($supported -join ', ')"
        exit 1
    }
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = New-DefaultOutputPath
}

Ensure-ParentDirectory -Path $OutputPath

Write-Host "RunningHub I2I"
Write-Host "ImageCount: $($allImagePaths.Count)"
foreach ($path in $allImagePaths) {
    Write-Host "ImagePath: $path"
}
Write-Host "OutputPath: $OutputPath"

$uploadImagePaths = $allImagePaths
$tempCopyInfo = $null
if (-not $DisableTempCopies) {
    try {
        $tempCopyInfo = New-TempImageCopies -Paths $allImagePaths
        $uploadImagePaths = $tempCopyInfo.Paths
        Write-Host "TempCopies: enabled"
    } catch {
        Remove-TempImageCopies -TempCopyInfo $tempCopyInfo
        Write-Error "Failed to prepare temp image copies: $_"
        exit 1
    }
} else {
    Write-Host "TempCopies: disabled"
}

$inputImageUrls = @()
foreach ($path in $uploadImagePaths) {
    try {
        $uploadResponse = Invoke-RestMethod `
            -Uri "$BaseUrl/openapi/v2/media/upload/binary" `
            -Method Post `
            -Headers @{ Authorization = "Bearer $ApiKey" } `
            -Form @{ file = Get-Item -LiteralPath $path }
    } catch {
        Remove-TempImageCopies -TempCopyInfo $tempCopyInfo
        Write-Error "Upload failed for ${path}: $_"
        exit 1
    }

    if ($uploadResponse.code -ne 0) {
        Remove-TempImageCopies -TempCopyInfo $tempCopyInfo
        Write-Error "Upload failed for ${path}: $($uploadResponse.msg)"
        exit 1
    }

    $inputImageUrl = $uploadResponse.data.download_url
    if ([string]::IsNullOrWhiteSpace($inputImageUrl)) {
        Remove-TempImageCopies -TempCopyInfo $tempCopyInfo
        Write-Error "Upload succeeded but no download_url was returned for ${path}."
        exit 1
    }

    $inputImageUrls += $inputImageUrl
}

Remove-TempImageCopies -TempCopyInfo $tempCopyInfo

$imageNodeIds = @("2", "5", "6", "7", "8", "9", "11", "12", "14", "13")
$nodeInfoList = @(
    @{
        nodeId = "1"
        fieldName = "resolution"
        fieldValue = $Resolution
    },
    @{
        nodeId = "1"
        fieldName = "quality"
        fieldValue = $Quality
    },
    @{
        nodeId = "1"
        fieldName = "aspectRatio"
        fieldValue = $AspectRatio
    },
    @{
        nodeId = "10"
        fieldName = "编辑文本"
        fieldValue = $Prompt
    }
)

for ($i = 0; $i -lt $inputImageUrls.Count; $i++) {
    $nodeInfoList += @{
        nodeId = $imageNodeIds[$i]
        fieldName = "image"
        fieldValue = $inputImageUrls[$i]
    }
}

$createBody = @{
    apiKey = $ApiKey
    workflowId = $WorkflowId
    nodeInfoList = $nodeInfoList
} | ConvertTo-Json -Depth 10

try {
    $createResponse = Invoke-RestMethod `
        -Uri "$BaseUrl/task/openapi/create" `
        -Method Post `
        -Headers @{ "Content-Type" = "application/json" } `
        -Body $createBody
} catch {
    Write-Error "Create request failed: $_"
    exit 1
}

if ($createResponse.code -ne 0) {
    Write-Error "Create task failed: $($createResponse.msg)"
    exit 1
}

$taskId = $createResponse.data.taskId
Write-Host "TaskId: $taskId"

$queryHeaders = @{
    "Content-Type" = "application/json"
    "Authorization" = "Bearer $ApiKey"
}

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

    $resultImageUrl = $null
    if ($queryResponse.results -and $queryResponse.results.Count -gt 0) {
        $resultImageUrl = $queryResponse.results[0].url
    }

    if ([string]::IsNullOrWhiteSpace($resultImageUrl)) {
        Write-Error "Task succeeded but no image URL was returned."
        Write-Result -TaskId $taskId -Status "SUCCESS_NO_URL"
        exit 1
    }

    try {
        Invoke-WebRequest -Uri $resultImageUrl -OutFile $OutputPath -UseBasicParsing
    } catch {
        Write-Error "Download failed: $_"
        Write-Result -TaskId $taskId -Status "SUCCESS_DOWNLOAD_FAILED" -ImageUrl $resultImageUrl
        exit 1
    }

    $file = Get-Item -LiteralPath $OutputPath
    $sizeMb = [math]::Round(($file.Length / 1MB), 2)
    Write-Host "Done: $OutputPath ($sizeMb MB)"
    Write-Result -TaskId $taskId -Status "SUCCESS" -OutputPath $OutputPath -ImageUrl $resultImageUrl
    exit 0
}

Write-Warning "Task is still running after $elapsed seconds."
Write-Result -TaskId $taskId -Status "TIMEOUT"
exit 2
