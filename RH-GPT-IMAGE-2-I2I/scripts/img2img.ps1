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

    [string]$WorkflowId = "",

    [ValidateSet("1:1", "2:3", "3:2", "3:4", "4:3", "4:5", "5:4", "9:16", "16:9", "21:9")]
    [string]$AspectRatio = "4:5",

    [ValidateSet("", "low", "medium", "high")]
    [string]$Quality = "",

    [ValidateSet("1k", "2k", "4k")]
    [string]$Resolution = "1k",

    [long]$Seed = 0,

    [string]$GenerationNodeId = "",

    [int[]]$PollDelays = @(60, 30, 30, 60, 60, 60, 60, 60, 60),

    [int64]$MaxUploadBytes = 4194304,

    [int]$MaxUploadEdge = 2048,

    [int]$JpegQuality = 90,

    [int]$RequestRetries = 3,

    [int]$RetryDelaySeconds = 8,

    [switch]$DisableTempCopies
)

$ErrorActionPreference = "Stop"
$BaseUrl = "https://www.runninghub.cn"
$DefaultWorkflowId = "2047956784060567554"
$StableWorkflowId = "2052988540669177857"

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
        $sourceFile = Get-Item -LiteralPath $sourcePath
        if ($sourceFile.Length -gt $MaxUploadBytes) {
            $copyPath = Join-Path $tempRoot ("input_{0:D2}.jpg" -f ($i + 1))
            Convert-ToUploadJpeg -SourcePath $sourcePath -DestinationPath $copyPath
            $preparedFile = Get-Item -LiteralPath $copyPath
            $sizeMb = [math]::Round(($preparedFile.Length / 1MB), 2)
            Write-Host "PreparedUpload: $sourcePath -> $copyPath ($sizeMb MB)"
        } else {
            $copyPath = Join-Path $tempRoot ("input_{0:D2}{1}" -f ($i + 1), $extension)
            Copy-Item -LiteralPath $sourcePath -Destination $copyPath -Force
        }
        $copies += $copyPath
    }

    return @{
        Root = $tempRoot
        Paths = $copies
    }
}

function Convert-ToUploadJpeg {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    Add-Type -AssemblyName System.Drawing
    $image = $null
    $bitmap = $null
    $graphics = $null
    $encoderParams = $null

    try {
        $image = [System.Drawing.Image]::FromFile($SourcePath)
        $longEdge = [Math]::Max($image.Width, $image.Height)
        $scale = [Math]::Min(1.0, [double]$MaxUploadEdge / [double]$longEdge)
        $width = [Math]::Max(1, [int][Math]::Round($image.Width * $scale))
        $height = [Math]::Max(1, [int][Math]::Round($image.Height * $scale))

        $bitmap = New-Object System.Drawing.Bitmap($width, $height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.Clear([System.Drawing.Color]::White)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.DrawImage($image, 0, 0, $width, $height)

        $jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
            Where-Object { $_.MimeType -eq "image/jpeg" } |
            Select-Object -First 1
        $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
            [System.Drawing.Imaging.Encoder]::Quality,
            [int64]$JpegQuality
        )
        $bitmap.Save($DestinationPath, $jpegCodec, $encoderParams)
    } finally {
        if ($encoderParams) { $encoderParams.Dispose() }
        if ($graphics) { $graphics.Dispose() }
        if ($bitmap) { $bitmap.Dispose() }
        if ($image) { $image.Dispose() }
    }
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

$useStableWorkflow = $Resolution -in @("2k", "4k")
if ([string]::IsNullOrWhiteSpace($WorkflowId)) {
    if ($useStableWorkflow) {
        $WorkflowId = $StableWorkflowId
    } else {
        $WorkflowId = $DefaultWorkflowId
    }
}

if ([string]::IsNullOrWhiteSpace($GenerationNodeId)) {
    if ($useStableWorkflow) {
        $GenerationNodeId = "1"
    } else {
        $GenerationNodeId = "15"
    }
}

$promptNodeId = "10"
$imageNodeIds = @("2", "5", "6", "7", "8", "11", "9", "12", "14", "13")
if ($useStableWorkflow) {
    $promptNodeId = "13"
    $imageNodeIds = @("3", "4", "5", "6", "7", "9", "10", "11", "12", "8")
    if ([string]::IsNullOrWhiteSpace($Quality)) {
        $Quality = "medium"
    }
} elseif (-not [string]::IsNullOrWhiteSpace($Quality)) {
    Write-Warning "Ignoring -Quality for the default 1K I2I workflow; that workflow does not expose a quality field."
    $Quality = ""
}

Write-Host "RunningHub I2I"
Write-Host "ImageCount: $($allImagePaths.Count)"
foreach ($path in $allImagePaths) {
    Write-Host "ImagePath: $path"
}
Write-Host "WorkflowId: $WorkflowId"
Write-Host "AspectRatio: $AspectRatio"
Write-Host "Resolution: $Resolution"
if (-not [string]::IsNullOrWhiteSpace($Quality)) {
    Write-Host "Quality: $Quality"
}
Write-Host "Seed: $Seed"
Write-Host "GenerationNodeId: $GenerationNodeId"
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
        $uploadResponse = Invoke-WithRetry -Label "Upload $path" -Operation {
            Invoke-RestMethod `
                -Uri "$BaseUrl/openapi/v2/media/upload/binary" `
                -Method Post `
                -Headers @{ Authorization = "Bearer $ApiKey" } `
                -Form @{ file = Get-Item -LiteralPath $path }
        }
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

$nodeInfoList = @(
    @{
        nodeId = $GenerationNodeId
        fieldName = "resolution"
        fieldValue = $Resolution
    },
    @{
        nodeId = $GenerationNodeId
        fieldName = "aspectRatio"
        fieldValue = $AspectRatio
    },
    @{
        nodeId = $GenerationNodeId
        fieldName = "seed"
        fieldValue = $Seed
    },
    @{
        nodeId = $promptNodeId
        fieldName = "编辑文本"
        fieldValue = $Prompt
    }
)

if (-not [string]::IsNullOrWhiteSpace($Quality)) {
    $nodeInfoList += @{
        nodeId = $GenerationNodeId
        fieldName = "quality"
        fieldValue = $Quality
    }
}

for ($i = 0; $i -lt $inputImageUrls.Count; $i++) {
    $nodeInfoList += @{
        nodeId = $imageNodeIds[$i]
        fieldName = "image"
        fieldValue = $inputImageUrls[$i]
    }
}

for ($i = $inputImageUrls.Count; $i -lt $imageNodeIds.Count; $i++) {
    $nodeInfoList += @{
        nodeId = $imageNodeIds[$i]
        fieldName = "image"
        fieldValue = ""
    }
}

$createBody = @{
    apiKey = $ApiKey
    workflowId = $WorkflowId
    nodeInfoList = $nodeInfoList
} | ConvertTo-Json -Depth 10

$createResponse = $null
for ($attempt = 1; $attempt -le $RequestRetries; $attempt++) {
    try {
        $createResponse = Invoke-RestMethod `
            -Uri "$BaseUrl/task/openapi/create" `
            -Method Post `
            -Headers @{ "Content-Type" = "application/json" } `
            -Body $createBody
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
        Invoke-WithRetry -Label "Download result" -Operation {
            Invoke-WebRequest -Uri $resultImageUrl -OutFile $OutputPath -UseBasicParsing
        } | Out-Null
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
