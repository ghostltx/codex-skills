# RH-GPT-IMAGE-2-I2I convenience entrypoint.
# Delegates to submit_i2i.ps1 with the default verified workflow.

param(
    [string]$ImagePath = "",

    [string[]]$ImagePaths = @(),

    [Parameter(Mandatory = $true)]
    [string]$Prompt,

    [string]$OutputPath = "",

    [string]$ApiKey = "12b7c9e5908c4daea92a98983306cb6b",

    [string]$WorkflowId = "2047956784060567554",

    [ValidateSet("1:1", "2:3", "3:2", "3:4", "4:3", "4:5", "5:4", "9:16", "16:9", "21:9")]
    [string]$AspectRatio = "4:5",

    [ValidateSet("", "low", "medium", "high")]
    [string]$Quality = "",

    [ValidateSet("", "1k", "2k")]
    [string]$Resolution = "2k",

    [long]$Seed = 0,

    [string]$GenerationNodeId = "",

    [int[]]$PollDelays = @(30, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5),

    [int64]$MaxUploadBytes = 4194304,

    [int]$MaxUploadEdge = 2048,

    [int]$JpegQuality = 90,

    [int]$RequestRetries = 3,

    [int]$RetryDelaySeconds = 8,

    [switch]$DisableTempCopies
)

$ErrorActionPreference = "Stop"

$allImagePaths = @()
if ($ImagePaths -and $ImagePaths.Count -gt 0) {
    $allImagePaths += $ImagePaths
} elseif (-not [string]::IsNullOrWhiteSpace($ImagePath)) {
    $allImagePaths += $ImagePath
}

if ($allImagePaths.Count -lt 1) {
    Write-Error "Provide at least one image with -ImagePaths or -ImagePath."
    exit 1
}

$submitScript = Join-Path $PSScriptRoot "submit_i2i.ps1"
$arguments = @{
    WorkflowId = $WorkflowId
    ImagePaths = $allImagePaths
    Prompt = $Prompt
    ApiKey = $ApiKey
    AspectRatio = $AspectRatio
    Resolution = $Resolution
    Seed = $Seed
    PollDelays = $PollDelays
    RequestRetries = $RequestRetries
    RetryDelaySeconds = $RetryDelaySeconds
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) { $arguments.OutputPath = $OutputPath }
if (-not [string]::IsNullOrWhiteSpace($Quality)) { $arguments.Quality = $Quality }
if (-not [string]::IsNullOrWhiteSpace($GenerationNodeId)) { $arguments.GenerationNodeId = $GenerationNodeId }
if ($DisableTempCopies) { $arguments.DisableTempCopies = $true }

& $submitScript @arguments
exit $LASTEXITCODE
