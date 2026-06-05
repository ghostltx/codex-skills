param(
  [switch]$Check,
  [switch]$List,
  [string]$Info = "",
  [string]$Endpoint = "",
  [string]$Prompt = "",
  [string[]]$ImagePaths = @(),
  [string[]]$Param = @(),
  [string]$Output = "",
  [string]$ApiKey = "",
  [string]$Type = "",
  [string]$Task = ""
)

$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "runninghub_openapi.py"
if (-not (Test-Path -LiteralPath $scriptPath)) {
  Write-Error "Missing bundled script: $scriptPath"
  exit 1
}

$argsList = @($scriptPath)

if ($Check) { $argsList += "--check" }
if ($List) { $argsList += "--list" }
if (-not [string]::IsNullOrWhiteSpace($Info)) { $argsList += @("--info", $Info) }
if (-not [string]::IsNullOrWhiteSpace($Endpoint)) { $argsList += @("--endpoint", $Endpoint) }
if (-not [string]::IsNullOrWhiteSpace($Prompt)) { $argsList += @("--prompt", $Prompt) }
foreach ($imagePath in $ImagePaths) {
  $argsList += @("--image", $imagePath)
}
foreach ($item in $Param) {
  $argsList += @("--param", $item)
}
if (-not [string]::IsNullOrWhiteSpace($Output)) { $argsList += @("--output", $Output) }
if (-not [string]::IsNullOrWhiteSpace($ApiKey)) { $argsList += @("--api-key", $ApiKey) }
if (-not [string]::IsNullOrWhiteSpace($Type)) { $argsList += @("--type", $Type) }
if (-not [string]::IsNullOrWhiteSpace($Task)) { $argsList += @("--task", $Task) }

& python @argsList
exit $LASTEXITCODE
