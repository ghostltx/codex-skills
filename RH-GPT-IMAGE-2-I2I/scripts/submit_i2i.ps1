# Generic RunningHub image-to-image workflow submitter.

param(
    [Parameter(Mandatory = $true)]
    [string]$WorkflowId,

    [Parameter(Mandatory = $true)]
    [string[]]$ImagePaths,

    [Parameter(Mandatory = $true)]
    [string]$Prompt,

    [string]$OutputPath = "",

    [string]$ApiKey = "12b7c9e5908c4daea92a98983306cb6b",

    [ValidateSet("1:1", "2:3", "3:2", "3:4", "4:3", "4:5", "5:4", "9:16", "16:9", "21:9")]
    [string]$AspectRatio = "4:5",

    [ValidateSet("", "1k", "2k")]
    [string]$Resolution = "2k",

    [ValidateSet("", "low", "medium", "high")]
    [string]$Quality = "",

    [long]$Seed = 0,

    [string[]]$ImageNodeIds = @(),

    [string]$PromptNodeId = "",

    [string]$PromptFieldName = "",

    [string]$GenerationNodeId = "",

    [int]$MaxImages = 0,

    [int[]]$PollDelays = @(30, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5),

    [int]$RequestRetries = 3,

    [int]$RetryDelaySeconds = 8,

    [switch]$DisableTempCopies
)

$ErrorActionPreference = "Stop"
$BaseUrl = "https://www.runninghub.cn"

function New-DefaultOutputPath {
    $desktop = [Environment]::GetFolderPath("Desktop")
    if ([string]::IsNullOrWhiteSpace($desktop)) { $desktop = (Get-Location).Path }
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    return (Join-Path $desktop "runninghub_generic_i2i_$timestamp.png")
}

function Ensure-ParentDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)
    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Operation,
        [Parameter(Mandatory = $true)][string]$Label
    )
    for ($attempt = 1; $attempt -le $RequestRetries; $attempt++) {
        try { return & $Operation } catch {
            if ($attempt -ge $RequestRetries) { throw }
            Write-Warning "$Label failed on attempt $attempt/$RequestRetries`: $_"
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }
}

function New-TempCopies {
    param([Parameter(Mandatory = $true)][string[]]$Paths)
    $root = Join-Path ([IO.Path]::GetTempPath()) ("rh_generic_i2i_" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    $copies = @()
    for ($i = 0; $i -lt $Paths.Count; $i++) {
        $ext = [IO.Path]::GetExtension($Paths[$i])
        $copy = Join-Path $root ("input_{0:D2}{1}" -f ($i + 1), $ext)
        Copy-Item -LiteralPath $Paths[$i] -Destination $copy -Force
        $copies += $copy
    }
    return @{ Root = $root; Paths = $copies }
}

function Remove-TempCopies {
    param($Info)
    if (-not $Info) { return }
    foreach ($path in $Info.Paths) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
    if (Test-Path -LiteralPath $Info.Root) {
        try {
            [IO.Directory]::Delete($Info.Root, $false)
        } catch {
            Write-Warning "Could not remove temp directory $($Info.Root): $_"
        }
    }
}

function Get-WorkflowNodes {
    param([Parameter(Mandatory = $true)][string]$WorkflowId)
    $body = @{ apiKey = $ApiKey; workflowId = $WorkflowId } | ConvertTo-Json
    $response = Invoke-WithRetry -Label "Get workflow JSON" -Operation {
        Invoke-RestMethod `
            -Uri "$BaseUrl/api/openapi/getJsonApiFormat" `
            -Method Post `
            -Headers @{ Authorization = "Bearer $ApiKey"; "Content-Type" = "application/json" } `
            -Body $body
    }
    if ($response.code -ne 0) {
        throw "Get workflow JSON failed: $($response.msg)"
    }
    if ([string]::IsNullOrWhiteSpace($response.data.prompt)) {
        throw "Workflow JSON response did not include data.prompt."
    }
    return ($response.data.prompt | ConvertFrom-Json)
}

function Get-InputNames {
    param($Node)
    if (-not $Node.inputs) { return @() }
    return @($Node.inputs.PSObject.Properties | ForEach-Object { $_.Name })
}

function Detect-WorkflowFields {
    param($PromptGraph)
    $loadImageNodeIds = @()
    $detectedPromptNodeId = ""
    $detectedPromptFieldName = ""
    $detectedGenerationNodeId = ""
    $bestGenerationScore = -1

    foreach ($property in $PromptGraph.PSObject.Properties) {
        $nodeId = [string]$property.Name
        $node = $property.Value
        $inputs = Get-InputNames -Node $node

        if ($node.class_type -eq "LoadImage" -and $inputs -contains "image") {
            $loadImageNodeIds += $nodeId
        }

        foreach ($candidate in @("编辑文本", "text", "positive", "prompt")) {
            if ([string]::IsNullOrWhiteSpace($detectedPromptNodeId) -and $inputs -contains $candidate) {
                $detectedPromptNodeId = $nodeId
                $detectedPromptFieldName = $candidate
                break
            }
        }

        $score = 0
        foreach ($candidate in @("resolution", "aspectRatio", "seed", "quality")) {
            if ($inputs -contains $candidate) { $score++ }
        }
        if ($score -gt $bestGenerationScore) {
            $bestGenerationScore = $score
            $detectedGenerationNodeId = $nodeId
        }
    }

    $detectedImageNodeIds = @()
    if (-not [string]::IsNullOrWhiteSpace($detectedGenerationNodeId)) {
        $generationNode = $PromptGraph.PSObject.Properties[$detectedGenerationNodeId].Value
        $imageLinks = @()
        foreach ($input in $generationNode.inputs.PSObject.Properties) {
            if ($input.Name -match '^image(\d*)$' -and $input.Value -is [array] -and $input.Value.Count -gt 0) {
                $slot = if ([string]::IsNullOrWhiteSpace($Matches[1])) { 1 } else { [int]$Matches[1] }
                $linkedNodeId = [string]$input.Value[0]
                if ($loadImageNodeIds -contains $linkedNodeId) {
                    $imageLinks += [pscustomobject]@{ Slot = $slot; NodeId = $linkedNodeId }
                }
            }
        }
        $detectedImageNodeIds = @($imageLinks | Sort-Object Slot | ForEach-Object { $_.NodeId })

        $promptInput = $generationNode.inputs.PSObject.Properties["prompt"]
        if ($promptInput -and $promptInput.Value -is [array] -and $promptInput.Value.Count -gt 0) {
            $linkedPromptNodeId = [string]$promptInput.Value[0]
            $linkedPromptNode = $PromptGraph.PSObject.Properties[$linkedPromptNodeId].Value
            if ($linkedPromptNode) {
                $linkedPromptInputs = Get-InputNames -Node $linkedPromptNode
                foreach ($candidate in @("编辑文本", "text", "positive", "prompt")) {
                    if ($linkedPromptInputs -contains $candidate) {
                        $detectedPromptNodeId = $linkedPromptNodeId
                        $detectedPromptFieldName = $candidate
                        break
                    }
                }
            }
        }
    }

    if ($detectedImageNodeIds.Count -eq 0) {
        $detectedImageNodeIds = @($loadImageNodeIds | Sort-Object { [int]$_ })
    }

    return @{
        ImageNodeIds = $detectedImageNodeIds
        PromptNodeId = $detectedPromptNodeId
        PromptFieldName = $detectedPromptFieldName
        GenerationNodeId = $detectedGenerationNodeId
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

if ($ImagePaths.Count -lt 1) {
    Write-Error "Provide at least one local image path."
    exit 1
}

$supported = @(".png", ".jpg", ".jpeg", ".webp")
foreach ($path in $ImagePaths) {
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Error "Image file does not exist: $path"
        exit 1
    }
    $ext = [IO.Path]::GetExtension($path).ToLowerInvariant()
    if ($ext -notin $supported) {
        Write-Error "Unsupported image format: $ext. Supported: $($supported -join ', ')"
        exit 1
    }
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = New-DefaultOutputPath }
Ensure-ParentDirectory -Path $OutputPath

$workflowGraph = Get-WorkflowNodes -WorkflowId $WorkflowId
$detected = Detect-WorkflowFields -PromptGraph $workflowGraph
if ($ImageNodeIds.Count -eq 0) { $ImageNodeIds = @($detected.ImageNodeIds) }
if ([string]::IsNullOrWhiteSpace($PromptNodeId)) { $PromptNodeId = $detected.PromptNodeId }
if ([string]::IsNullOrWhiteSpace($PromptFieldName)) { $PromptFieldName = $detected.PromptFieldName }
if ([string]::IsNullOrWhiteSpace($GenerationNodeId)) { $GenerationNodeId = $detected.GenerationNodeId }

if ($ImageNodeIds.Count -eq 0) {
    Write-Error "Could not detect image nodes. Pass -ImageNodeIds manually."
    exit 1
}
if ([string]::IsNullOrWhiteSpace($PromptNodeId) -or [string]::IsNullOrWhiteSpace($PromptFieldName)) {
    Write-Error "Could not detect prompt node. Pass -PromptNodeId and -PromptFieldName manually."
    exit 1
}
if ($ImagePaths.Count -gt $ImageNodeIds.Count) {
    Write-Error "Workflow has $($ImageNodeIds.Count) detected image nodes, but $($ImagePaths.Count) images were provided."
    exit 1
}

if ($MaxImages -gt 0 -and $MaxImages -lt $ImageNodeIds.Count) {
    $ImageNodeIds = @($ImageNodeIds | Select-Object -First $MaxImages)
}

Write-Host "RunningHub Generic I2I"
Write-Host "WorkflowId: $WorkflowId"
Write-Host "ImageCount: $($ImagePaths.Count)"
Write-Host "ImageNodeIds: $($ImageNodeIds -join ',')"
Write-Host "PromptNodeId: $PromptNodeId"
Write-Host "PromptFieldName: $PromptFieldName"
Write-Host "GenerationNodeId: $GenerationNodeId"
Write-Host "OutputPath: $OutputPath"

$uploadPaths = $ImagePaths
$tempInfo = $null
if (-not $DisableTempCopies) {
    try {
        $tempInfo = New-TempCopies -Paths $ImagePaths
        $uploadPaths = $tempInfo.Paths
        Write-Host "TempCopies: enabled"
    } catch {
        Remove-TempCopies -Info $tempInfo
        Write-Error "Failed to prepare temp image copies: $_"
        exit 1
    }
}

$uploadedFileNames = @()
foreach ($path in $uploadPaths) {
    try {
        $uploadResponse = Invoke-WithRetry -Label "Upload $path" -Operation {
            Invoke-RestMethod `
                -Uri "$BaseUrl/openapi/v2/media/upload/binary" `
                -Method Post `
                -Headers @{ Authorization = "Bearer $ApiKey" } `
                -Form @{ file = Get-Item -LiteralPath $path }
        }
    } catch {
        Remove-TempCopies -Info $tempInfo
        Write-Error "Upload failed for ${path}: $_"
        exit 1
    }
    if ($uploadResponse.code -ne 0) {
        Remove-TempCopies -Info $tempInfo
        Write-Error "Upload failed for ${path}: $($uploadResponse.msg)"
        exit 1
    }
    $fileName = $uploadResponse.data.fileName
    if ([string]::IsNullOrWhiteSpace($fileName)) {
        $fileName = $uploadResponse.data.download_url
    }
    if ([string]::IsNullOrWhiteSpace($fileName)) {
        Remove-TempCopies -Info $tempInfo
        Write-Error "Upload succeeded but no fileName or download_url was returned for ${path}."
        exit 1
    }
    $uploadedFileNames += $fileName
}
Remove-TempCopies -Info $tempInfo

$nodeInfoList = @(
    @{ nodeId = $PromptNodeId; fieldName = $PromptFieldName; fieldValue = $Prompt }
)

if (-not [string]::IsNullOrWhiteSpace($GenerationNodeId)) {
    if (-not [string]::IsNullOrWhiteSpace($Resolution)) {
        $nodeInfoList += @{ nodeId = $GenerationNodeId; fieldName = "resolution"; fieldValue = $Resolution }
    }
    if (-not [string]::IsNullOrWhiteSpace($AspectRatio)) {
        $nodeInfoList += @{ nodeId = $GenerationNodeId; fieldName = "aspectRatio"; fieldValue = $AspectRatio }
    }
    $nodeInfoList += @{ nodeId = $GenerationNodeId; fieldName = "seed"; fieldValue = $Seed }
    if (-not [string]::IsNullOrWhiteSpace($Quality)) {
        $nodeInfoList += @{ nodeId = $GenerationNodeId; fieldName = "quality"; fieldValue = $Quality }
    }
}

for ($i = 0; $i -lt $uploadedFileNames.Count; $i++) {
    $nodeInfoList += @{ nodeId = $ImageNodeIds[$i]; fieldName = "image"; fieldValue = $uploadedFileNames[$i] }
}
for ($i = $uploadedFileNames.Count; $i -lt $ImageNodeIds.Count; $i++) {
    $nodeInfoList += @{ nodeId = $ImageNodeIds[$i]; fieldName = "image"; fieldValue = "" }
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

    if ($createResponse.code -eq 0) { break }
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

$queryHeaders = @{ "Content-Type" = "application/json"; "Authorization" = "Bearer $ApiKey" }
$elapsed = 0
$lastStatus = "UNKNOWN"
foreach ($delay in $PollDelays) {
    $elapsed += $delay
    Write-Host "Waiting ${delay}s before query (${elapsed}s elapsed)..."
    Start-Sleep -Seconds $delay

    try {
        $queryResponse = Invoke-RestMethod `
            -Uri "$BaseUrl/openapi/v2/query" `
            -Method Post `
            -Headers $queryHeaders `
            -Body (@{ taskId = $taskId } | ConvertTo-Json)
    } catch {
        Write-Warning "Query failed at ${elapsed}s: $_"
        continue
    }

    Write-Host "Status: $($queryResponse.status)"
    $lastStatus = $queryResponse.status
    if ($queryResponse.status -eq "FAILED") {
        Write-Error "Task failed: $($queryResponse.failedReason | ConvertTo-Json -Depth 5 -Compress)"
        Write-Result -TaskId $taskId -Status "FAILED"
        exit 1
    }
    if ($queryResponse.status -ne "SUCCESS") { continue }

    $resultUrl = $null
    if ($queryResponse.results -and $queryResponse.results.Count -gt 0) {
        $resultUrl = $queryResponse.results[0].url
        if ([string]::IsNullOrWhiteSpace($resultUrl)) { $resultUrl = $queryResponse.results[0].fileUrl }
        if ([string]::IsNullOrWhiteSpace($resultUrl)) { $resultUrl = $queryResponse.results[0].download_url }
    }

    if ([string]::IsNullOrWhiteSpace($resultUrl)) {
        try {
            $outputsResponse = Invoke-RestMethod `
                -Uri "$BaseUrl/task/openapi/outputs" `
                -Method Post `
                -Headers $queryHeaders `
                -Body (@{ apiKey = $ApiKey; taskId = $taskId } | ConvertTo-Json)
            if ($outputsResponse.code -eq 0 -and $outputsResponse.data -and $outputsResponse.data.Count -gt 0) {
                $resultUrl = $outputsResponse.data[0].fileUrl
                if ([string]::IsNullOrWhiteSpace($resultUrl)) { $resultUrl = $outputsResponse.data[0].url }
                if ([string]::IsNullOrWhiteSpace($resultUrl)) { $resultUrl = $outputsResponse.data[0].download_url }
            }
        } catch {
            Write-Warning "Fallback output query failed: $_"
        }
    }

    if ([string]::IsNullOrWhiteSpace($resultUrl)) {
        Write-Error "Task succeeded but no image URL was returned."
        Write-Result -TaskId $taskId -Status "SUCCESS_NO_URL"
        exit 1
    }

    try {
        Invoke-WithRetry -Label "Download result" -Operation {
            Invoke-WebRequest -Uri $resultUrl -OutFile $OutputPath -UseBasicParsing
        } | Out-Null
    } catch {
        Write-Error "Download failed: $_"
        Write-Result -TaskId $taskId -Status "SUCCESS_DOWNLOAD_FAILED" -ImageUrl $resultUrl
        exit 1
    }

    $file = Get-Item -LiteralPath $OutputPath
    $sizeMb = [math]::Round(($file.Length / 1MB), 2)
    Write-Host "Done: $OutputPath ($sizeMb MB)"
    Write-Result -TaskId $taskId -Status "SUCCESS" -OutputPath $OutputPath -ImageUrl $resultUrl
    exit 0
}

Write-Warning "Task did not return an image within $elapsed seconds. Last status: $lastStatus. If it is still RUNNING on RunningHub, retry query/download later with TASK_ID=$taskId."
Write-Result -TaskId $taskId -Status "TIMEOUT"
exit 2
