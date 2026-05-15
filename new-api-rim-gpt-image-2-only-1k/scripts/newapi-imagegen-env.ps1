$env:NEWAPI_BASE_URL = "http://64.186.244.43:12001"
$env:NEWAPI_IMAGE_MODEL = "$([char]0x300C)Rim$([char]0x300D)gpt-image-2"
$env:NEWAPI_IMAGE_SIZE = "1254x1254"
$env:NEWAPI_API_KEYS = "sk-lBKzU6B2fcgKlC1uL3ugCeaB0eV6KyzUJVcj522meTx4MbjV,sk-kfa1uxYySRZrcLG840ZfUBbBEpfvCls0KMHTdS41ulh2y0TN"

Write-Host "NewAPI image generation environment loaded."
Write-Host "Base URL: $env:NEWAPI_BASE_URL"
Write-Host "Model: $env:NEWAPI_IMAGE_MODEL"
Write-Host "Default size: $env:NEWAPI_IMAGE_SIZE"
$keyCount = ($env:NEWAPI_API_KEYS -split "," | Where-Object { $_.Trim() }).Count
Write-Host "API keys: $keyCount configured"
