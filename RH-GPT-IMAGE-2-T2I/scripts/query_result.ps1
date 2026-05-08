# Backward-compatible result query. Downloads successful images to the desktop by default.

param(
    [Parameter(Mandatory = $true)]
    [string]$TaskId,

    [string]$OutputPath = "",

    [string]$ApiKey = "12b7c9e5908c4daea92a98983306cb6b"
)

$script = Join-Path $PSScriptRoot "query_task.ps1"
& $script -TaskId $TaskId -ApiKey $ApiKey -OutputPath $OutputPath -Download
exit $LASTEXITCODE
