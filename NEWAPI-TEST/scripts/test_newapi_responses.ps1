param(
  [Parameter(Mandatory = $true)]
  [string]$ApiKey,

  [string]$BaseUrl = "http://64.186.244.43:12001/v1",

  [string]$Prompt = "hi",

  [int]$MaxOutputTokens = 24
)

$ErrorActionPreference = "Stop"

$excludePattern = "image|seedream|gpt-image|embedding|tts|audio|whisper"
$base = $BaseUrl.TrimEnd("/")

function Invoke-NewApiJson {
  param(
    [string]$Uri,
    [string]$Method = "GET",
    [object]$Body = $null
  )

  $headers = @{
    Authorization = "Bearer $ApiKey"
  }

  if ($Body -ne $null) {
    $json = $Body | ConvertTo-Json -Depth 12 -Compress
    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -ContentType "application/json" -Body $json -TimeoutSec 60
  }

  return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -TimeoutSec 60
}

try {
  $modelsResponse = Invoke-NewApiJson -Uri "$base/models"
} catch {
  [pscustomobject]@{
    status = "error"
    message = "Failed to fetch model list: $($_.Exception.Message)"
  } | ConvertTo-Json -Depth 8
  exit 1
}

$models = @($modelsResponse.data |
  Where-Object { $_.id -and $_.id -notmatch $excludePattern } |
  Select-Object -ExpandProperty id -Unique)

$passed = New-Object System.Collections.Generic.List[object]
$generalPassed = New-Object System.Collections.Generic.List[object]
$failed = New-Object System.Collections.Generic.List[object]

foreach ($model in $models) {
  $body = @{
    model = $model
    input = $Prompt
    max_output_tokens = $MaxOutputTokens
    store = $false
  }

  try {
    $response = Invoke-NewApiJson -Method "POST" -Uri "$base/responses" -Body $body
    if ($response.object -eq "response" -and $response.status -eq "completed") {
      $text = ""
      try {
        $text = $response.output[0].content[0].text
      } catch {
        $text = ""
      }

      $passed.Add([pscustomobject]@{
        model = $model
        endpoint = "/responses"
        response = $text
        input_tokens = $response.usage.input_tokens
        output_tokens = $response.usage.output_tokens
        total_tokens = $response.usage.total_tokens
      }) | Out-Null

      if (-not [string]::IsNullOrWhiteSpace($text)) {
        $generalPassed.Add([pscustomobject]@{
          model = $model
          endpoint = "/responses"
          response = $text
          input_tokens = $response.usage.input_tokens
          output_tokens = $response.usage.output_tokens
          total_tokens = $response.usage.total_tokens
        }) | Out-Null
      }
    } else {
      $failed.Add([pscustomobject]@{
        model = $model
        error_code = "unknown"
        error_message = "Unexpected response status or shape"
      }) | Out-Null
    }
  } catch {
    $errorCode = ""
    $errorMessage = $_.Exception.Message

    try {
      $stream = $_.Exception.Response.GetResponseStream()
      if ($stream) {
        $reader = [System.IO.StreamReader]::new($stream)
        $raw = $reader.ReadToEnd()
        if ($raw) {
          $errorObj = $raw | ConvertFrom-Json
          $errorCode = $errorObj.error.code
          $errorMessage = $errorObj.error.message
        }
      }
    } catch {}

    $failed.Add([pscustomobject]@{
      model = $model
      error_code = $errorCode
      error_message = $errorMessage
      }) | Out-Null
  }

  $alreadyGeneralPassed = @($generalPassed | Where-Object { $_.model -eq $model }).Count -gt 0
  if (-not $alreadyGeneralPassed) {
    $chatBody = @{
      model = $model
      messages = @(
        @{
          role = "user"
          content = $Prompt
        }
      )
      max_tokens = $MaxOutputTokens
      temperature = 0
    }

    try {
      $chatResponse = Invoke-NewApiJson -Method "POST" -Uri "$base/chat/completions" -Body $chatBody
      $chatText = ""
      try {
        $chatText = $chatResponse.choices[0].message.content
      } catch {
        $chatText = ""
      }

      if (-not [string]::IsNullOrWhiteSpace($chatText)) {
        $generalPassed.Add([pscustomobject]@{
          model = $model
          endpoint = "/chat/completions"
          response = $chatText
          input_tokens = $chatResponse.usage.prompt_tokens
          output_tokens = $chatResponse.usage.completion_tokens
          total_tokens = $chatResponse.usage.total_tokens
        }) | Out-Null
      }
    } catch {}
  }
}

[pscustomobject]@{
  status = "ok"
  base_url = $base
  tested_model_count = $models.Count
  codex_passed_count = $passed.Count
  codex_passed = $passed
  general_passed_count = $generalPassed.Count
  general_passed = $generalPassed
  failed_count = $failed.Count
  failed_summary = $failed |
    Group-Object error_code, error_message |
    Sort-Object Count -Descending |
    Select-Object Count, Name
} | ConvertTo-Json -Depth 10
