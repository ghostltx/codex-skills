# Generic RunningHub text-to-image workflow submitter.

param(
    [Parameter(Mandatory = $true)]
    [string]$WorkflowId,

    [Parameter(Mandatory = $true)]
    [string]$Prompt,

    [string]$NegativePrompt = "",

    [string]$OutputPath = "",

    [string]$ApiKey = "12b7c9e5908c4daea92a98983306cb6b",

    [ValidateSet("", "1:1", "2:3", "3:2", "3:4", "4:3", "4:5", "5:4", "9:16", "16:9", "21:9")]
    [string]$AspectRatio = "",

    [ValidateSet("", "1k", "2k", "4k")]
    [string]$Resolution = "",

    [int]$Width = 0,

    [int]$Height = 0,

    [long]$Seed = 0,

    [int]$Steps = 0,

    [double]$Cfg = 0,

    [int]$BatchSize = 0,

    [ValidateSet("", "low", "medium", "high")]
    [string]$Quality = "",

    [string]$PromptNodeId = "",

    [string]$PromptFieldName = "",

    [string]$NegativePromptNodeId = "",

    [string]$NegativePromptFieldName = "",

    [string]$GenerationNodeId = "",

    [string]$SizeNodeId = "",

    [string]$SamplerNodeId = "",

    [int[]]$PollDelays = @(60, 30, 30, 60, 60, 60, 60, 60, 60),

    [int]$RequestRetries = 3,

    [int]$RetryDelaySeconds = 8
)

$ErrorActionPreference = "Stop"
$BaseUrl = "https://www.runninghub.cn"

function New-DefaultOutputPath {
    $desktop = [Environment]::GetFolderPath("Desktop")
    if ([string]::IsNullOrWhiteSpace($desktop)) { $desktop = (Get-Location).Path }
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    return (Join-Path $desktop "runninghub_generic_t2i_$timestamp.png")
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

function Get-UsageInfo {
    param($Response)
    $cost = $null
    $duration = $null
    if ($Response -and $Response.PSObject.Properties["usage"]) {
        $usage = $Response.PSObject.Properties["usage"].Value
        if ($usage) {
            if ($usage.PSObject.Properties["consumeMoney"]) {
                $cost = $usage.PSObject.Properties["consumeMoney"].Value
            }
            if (($null -eq $cost -or "$cost" -eq "") -and $usage.PSObject.Properties["thirdPartyConsumeMoney"]) {
                $cost = $usage.PSObject.Properties["thirdPartyConsumeMoney"].Value
            }
            if ($usage.PSObject.Properties["taskCostTime"]) {
                $duration = $usage.PSObject.Properties["taskCostTime"].Value
            }
        }
    }
    return @{ Cost = $cost; Duration = $duration }
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

function Get-NodeTextHint {
    param(
        [string]$NodeId,
        $Node
    )
    $parts = @($NodeId, $Node.class_type)
    foreach ($name in @("_meta", "title")) {
        if ($Node.PSObject.Properties[$name]) {
            $value = $Node.PSObject.Properties[$name].Value
            if ($value -is [string]) {
                $parts += $value
            } elseif ($value -and $value.PSObject.Properties["title"]) {
                $parts += [string]$value.PSObject.Properties["title"].Value
            }
        }
    }
    return (($parts | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join " ").ToLowerInvariant()
}

function Add-NodeField {
    param(
        [Parameter(Mandatory = $true)][ref]$List,
        [string]$NodeId,
        [string]$FieldName,
        $FieldValue
    )
    if ([string]::IsNullOrWhiteSpace($NodeId) -or [string]::IsNullOrWhiteSpace($FieldName)) { return }
    $List.Value += @{ nodeId = $NodeId; fieldName = $FieldName; fieldValue = $FieldValue }
}

function Get-FirstInputName {
    param(
        [string[]]$Inputs,
        [string[]]$Candidates
    )
    foreach ($candidate in $Candidates) {
        if ($Inputs -contains $candidate) { return $candidate }
    }
    return ""
}

function Detect-WorkflowFields {
    param($PromptGraph)

    $promptCandidates = @()
    $negativeCandidates = @()
    $detectedGenerationNodeId = ""
    $bestGenerationScore = -1
    $detectedSizeNodeId = ""
    $bestSizeScore = -1
    $detectedSamplerNodeId = ""
    $bestSamplerScore = -1

    foreach ($property in $PromptGraph.PSObject.Properties) {
        $nodeId = [string]$property.Name
        $node = $property.Value
        $inputs = Get-InputNames -Node $node
        $hint = Get-NodeTextHint -NodeId $nodeId -Node $node

        $textField = Get-FirstInputName -Inputs $inputs -Candidates @("编辑文本", "text", "positive", "prompt", "conditioning", "string")
        if (-not [string]::IsNullOrWhiteSpace($textField)) {
            $isNegative = ($hint -match "negative|负面|反向|neg") -or ($textField -match "negative")
            $candidate = [pscustomobject]@{ NodeId = $nodeId; FieldName = $textField; IsNegative = $isNegative; Hint = $hint }
            if ($isNegative) {
                $negativeCandidates += $candidate
            } else {
                $promptCandidates += $candidate
            }
        }

        $generationScore = 0
        foreach ($candidate in @("resolution", "aspectRatio", "seed", "quality")) {
            if ($inputs -contains $candidate) { $generationScore++ }
        }
        if ($generationScore -gt $bestGenerationScore) {
            $bestGenerationScore = $generationScore
            $detectedGenerationNodeId = $nodeId
        }

        $sizeScore = 0
        foreach ($candidate in @("width", "height", "batch_size", "batchSize")) {
            if ($inputs -contains $candidate) { $sizeScore++ }
        }
        if ($sizeScore -gt $bestSizeScore) {
            $bestSizeScore = $sizeScore
            $detectedSizeNodeId = $nodeId
        }

        $samplerScore = 0
        foreach ($candidate in @("seed", "steps", "cfg", "cfg_scale", "sampler_name", "scheduler")) {
            if ($inputs -contains $candidate) { $samplerScore++ }
        }
        if ($samplerScore -gt $bestSamplerScore) {
            $bestSamplerScore = $samplerScore
            $detectedSamplerNodeId = $nodeId
        }
    }

    if ($negativeCandidates.Count -eq 0) {
        $negativeCandidates = @($promptCandidates | Where-Object { $_.Hint -match "negative|负面|反向|neg" })
        $promptCandidates = @($promptCandidates | Where-Object { $_.Hint -notmatch "negative|负面|反向|neg" })
    }

    $positive = $null
    if ($promptCandidates.Count -gt 0) { $positive = $promptCandidates[0] }
    $negative = $null
    if ($negativeCandidates.Count -gt 0) { $negative = $negativeCandidates[0] }

    return @{
        PromptNodeId = if ($positive) { $positive.NodeId } else { "" }
        PromptFieldName = if ($positive) { $positive.FieldName } else { "" }
        NegativePromptNodeId = if ($negative) { $negative.NodeId } else { "" }
        NegativePromptFieldName = if ($negative) { $negative.FieldName } else { "" }
        GenerationNodeId = if ($bestGenerationScore -gt 0) { $detectedGenerationNodeId } else { "" }
        SizeNodeId = if ($bestSizeScore -gt 0) { $detectedSizeNodeId } else { "" }
        SamplerNodeId = if ($bestSamplerScore -gt 0) { $detectedSamplerNodeId } else { "" }
    }
}

function Write-Result {
    param(
        [string]$TaskId,
        [string]$Status,
        [string]$OutputPath = "",
        [string]$ImageUrl = "",
        $Cost = $null,
        $Duration = $null
    )
    Write-Host "TASK_ID=$TaskId"
    Write-Host "STATUS=$Status"
    if ($OutputPath) { Write-Host "OUTPUT_PATH=$OutputPath" }
    if ($ImageUrl) { Write-Host "IMAGE_URL=$ImageUrl" }
    if ($null -ne $Cost -and "$Cost" -ne "") { Write-Host "COST:¥$Cost" }
    if ($null -ne $Duration -and "$Duration" -ne "" -and "$Duration" -ne "0") { Write-Host "DURATION:${Duration}s" }
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = New-DefaultOutputPath }
Ensure-ParentDirectory -Path $OutputPath

$workflowGraph = Get-WorkflowNodes -WorkflowId $WorkflowId
$detected = Detect-WorkflowFields -PromptGraph $workflowGraph
if ([string]::IsNullOrWhiteSpace($PromptNodeId)) { $PromptNodeId = $detected.PromptNodeId }
if ([string]::IsNullOrWhiteSpace($PromptFieldName)) { $PromptFieldName = $detected.PromptFieldName }
if ([string]::IsNullOrWhiteSpace($NegativePromptNodeId)) { $NegativePromptNodeId = $detected.NegativePromptNodeId }
if ([string]::IsNullOrWhiteSpace($NegativePromptFieldName)) { $NegativePromptFieldName = $detected.NegativePromptFieldName }
if ([string]::IsNullOrWhiteSpace($GenerationNodeId)) { $GenerationNodeId = $detected.GenerationNodeId }
if ([string]::IsNullOrWhiteSpace($SizeNodeId)) { $SizeNodeId = $detected.SizeNodeId }
if ([string]::IsNullOrWhiteSpace($SamplerNodeId)) { $SamplerNodeId = $detected.SamplerNodeId }

if ([string]::IsNullOrWhiteSpace($PromptNodeId) -or [string]::IsNullOrWhiteSpace($PromptFieldName)) {
    Write-Error "Could not detect prompt node. Pass -PromptNodeId and -PromptFieldName manually."
    exit 1
}

Write-Host "RunningHub Generic T2I"
Write-Host "WorkflowId: $WorkflowId"
Write-Host "PromptNodeId: $PromptNodeId"
Write-Host "PromptFieldName: $PromptFieldName"
Write-Host "NegativePromptNodeId: $NegativePromptNodeId"
Write-Host "NegativePromptFieldName: $NegativePromptFieldName"
Write-Host "GenerationNodeId: $GenerationNodeId"
Write-Host "SizeNodeId: $SizeNodeId"
Write-Host "SamplerNodeId: $SamplerNodeId"
Write-Host "OutputPath: $OutputPath"

$nodeInfoList = @()
Add-NodeField -List ([ref]$nodeInfoList) -NodeId $PromptNodeId -FieldName $PromptFieldName -FieldValue $Prompt
if (-not [string]::IsNullOrWhiteSpace($NegativePrompt)) {
    Add-NodeField -List ([ref]$nodeInfoList) -NodeId $NegativePromptNodeId -FieldName $NegativePromptFieldName -FieldValue $NegativePrompt
}

if (-not [string]::IsNullOrWhiteSpace($GenerationNodeId)) {
    if (-not [string]::IsNullOrWhiteSpace($Resolution)) {
        Add-NodeField -List ([ref]$nodeInfoList) -NodeId $GenerationNodeId -FieldName "resolution" -FieldValue $Resolution
    }
    if (-not [string]::IsNullOrWhiteSpace($AspectRatio)) {
        Add-NodeField -List ([ref]$nodeInfoList) -NodeId $GenerationNodeId -FieldName "aspectRatio" -FieldValue $AspectRatio
    }
    if ($Seed -ne 0) {
        Add-NodeField -List ([ref]$nodeInfoList) -NodeId $GenerationNodeId -FieldName "seed" -FieldValue $Seed
    }
    if (-not [string]::IsNullOrWhiteSpace($Quality)) {
        Add-NodeField -List ([ref]$nodeInfoList) -NodeId $GenerationNodeId -FieldName "quality" -FieldValue $Quality
    }
}

if (-not [string]::IsNullOrWhiteSpace($SizeNodeId)) {
    if ($Width -gt 0) { Add-NodeField -List ([ref]$nodeInfoList) -NodeId $SizeNodeId -FieldName "width" -FieldValue $Width }
    if ($Height -gt 0) { Add-NodeField -List ([ref]$nodeInfoList) -NodeId $SizeNodeId -FieldName "height" -FieldValue $Height }
    if ($BatchSize -gt 0) { Add-NodeField -List ([ref]$nodeInfoList) -NodeId $SizeNodeId -FieldName "batch_size" -FieldValue $BatchSize }
}

if (-not [string]::IsNullOrWhiteSpace($SamplerNodeId)) {
    if ($Seed -ne 0) { Add-NodeField -List ([ref]$nodeInfoList) -NodeId $SamplerNodeId -FieldName "seed" -FieldValue $Seed }
    if ($Steps -gt 0) { Add-NodeField -List ([ref]$nodeInfoList) -NodeId $SamplerNodeId -FieldName "steps" -FieldValue $Steps }
    if ($Cfg -gt 0) { Add-NodeField -List ([ref]$nodeInfoList) -NodeId $SamplerNodeId -FieldName "cfg" -FieldValue $Cfg }
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
    $usageInfo = Get-UsageInfo -Response $queryResponse
    if ($queryResponse.status -eq "FAILED") {
        Write-Error "Task failed: $($queryResponse.failedReason | ConvertTo-Json -Depth 5 -Compress)"
        Write-Result -TaskId $taskId -Status "FAILED" -Cost $usageInfo.Cost -Duration $usageInfo.Duration
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
        Write-Result -TaskId $taskId -Status "SUCCESS_NO_URL" -Cost $usageInfo.Cost -Duration $usageInfo.Duration
        exit 1
    }

    try {
        Invoke-WithRetry -Label "Download result" -Operation {
            Invoke-WebRequest -Uri $resultUrl -OutFile $OutputPath -UseBasicParsing
        } | Out-Null
    } catch {
        Write-Error "Download failed: $_"
        Write-Result -TaskId $taskId -Status "SUCCESS_DOWNLOAD_FAILED" -ImageUrl $resultUrl -Cost $usageInfo.Cost -Duration $usageInfo.Duration
        exit 1
    }

    $file = Get-Item -LiteralPath $OutputPath
    $sizeMb = [math]::Round(($file.Length / 1MB), 2)
    Write-Host "Done: $OutputPath ($sizeMb MB)"
    Write-Result -TaskId $taskId -Status "SUCCESS" -OutputPath $OutputPath -ImageUrl $resultUrl -Cost $usageInfo.Cost -Duration $usageInfo.Duration
    exit 0
}

Write-Warning "Task is still running after $elapsed seconds."
Write-Result -TaskId $taskId -Status "TIMEOUT"
exit 2
