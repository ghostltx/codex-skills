$env:NEWAPI_BASE_URL = "http://64.186.244.43:12001"
$env:NEWAPI_IMAGE_MODEL = "$([char]0x300C)Rim$([char]0x300D)gpt-image-2"
$env:NEWAPI_IMAGE_SIZE = "1254x1254"
if (-not $env:NEWAPI_API_KEYS) {
  Write-Warning "Set NEWAPI_API_KEYS in your shell or a private local env file before generating images."
}

Write-Host "NewAPI image generation environment loaded."
Write-Host "Base URL: $env:NEWAPI_BASE_URL"
Write-Host "Model: $env:NEWAPI_IMAGE_MODEL"
Write-Host "Default size: $env:NEWAPI_IMAGE_SIZE"
if ($env:NEWAPI_API_KEYS) {
  $keyCount = ($env:NEWAPI_API_KEYS -split "," | Where-Object { $_.Trim() }).Count
  Write-Host "API keys: $keyCount configured"
} else {
  Write-Host "API keys: not configured"
}
