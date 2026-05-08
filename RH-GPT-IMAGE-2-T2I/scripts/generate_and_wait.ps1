# Backward-compatible entry point. Prefer generate_image.ps1 for new calls.

param(
    [Parameter(Mandatory = $true)]
    [string]$Prompt,

    [ValidateSet("1:1", "16:9", "9:16", "4:3", "3:4")]
    [string]$AspectRatio = "1:1",

    [long]$Seed = 0,

    [string]$OutputPath = "",

    [string]$ApiKey = "12b7c9e5908c4daea92a98983306cb6b",

    [string]$WorkflowId = "2047717286877863938"
)

$script = Join-Path $PSScriptRoot "generate_image.ps1"
& $script @PSBoundParameters
exit $LASTEXITCODE
