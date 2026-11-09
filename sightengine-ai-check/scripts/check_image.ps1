param(
    [Parameter(Position = 0)]
    [string]$ImagePath,

    [Parameter()]
    [string]$ImageUrl
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ImagePath) -and [string]::IsNullOrWhiteSpace($ImageUrl)) {
    throw "必须提供本地图片路径 (-ImagePath) 或图片网络地址 (-ImageUrl)。"
}

# 1. 尝试从环境变量获取 secret
$apiUser = "1625826518"
$apiSecret = $env:SIGHTENGINE_API_SECRET

# 2. 若未设置环境变量，从 OneDrive notepad.md 中读取
if ([string]::IsNullOrWhiteSpace($apiSecret)) {
    $notepadPath = Join-Path "C:\Users\ghost\OneDrive\Codex" "notepad.md"
    if (Test-Path -LiteralPath $notepadPath) {
        $lines = Get-Content -LiteralPath $notepadPath -Encoding UTF8
        $matchLine = $lines | Where-Object { $_ -like "*Sightengine API*" } | Select-Object -Last 1
        if ($matchLine -and $matchLine -match 'API secret\s*=\s*([A-Za-z0-9]+)') {
            $apiSecret = $Matches[1]
        }
    }
}

if ([string]::IsNullOrWhiteSpace($apiSecret)) {
    throw "未找到 Sightengine API Secret，请检查环境变量 SIGHTENGINE_API_SECRET 或 notepad.md 文件中的配置。"
}

$apiUrl = "https://api.sightengine.com/1.0/check.json"
$rawResponse = $null

if (-not [string]::IsNullOrWhiteSpace($ImagePath)) {
    $resolved = (Resolve-Path -LiteralPath $ImagePath).Path
    $fileItem = Get-Item -LiteralPath $resolved
    if ($fileItem.PSIsContainer) {
        throw "ImagePath 必须指向具体文件: $resolved"
    }

    # 单张图不能超过 12MB
    if ($fileItem.Length -gt 12MB) {
        throw "图片文件大小超过 12MB 限制: $([math]::Round($fileItem.Length / 1MB, 2)) MB"
    }

    $rawResponse = & curl.exe -s -X POST $apiUrl `
        -F "models=genai" `
        -F "api_user=$apiUser" `
        -F "api_secret=$apiSecret" `
        -F "media=@$resolved"
}
else {
    $rawResponse = & curl.exe -s -X POST $apiUrl `
        -F "models=genai" `
        -F "api_user=$apiUser" `
        -F "api_secret=$apiSecret" `
        -F "url=$ImageUrl"
}

if ([string]::IsNullOrWhiteSpace($rawResponse)) {
    throw "Sightengine API 未返回任何数据。"
}

try {
    $json = $rawResponse | ConvertFrom-Json
}
catch {
    throw "解析 Sightengine 返回的 JSON 失败: $rawResponse"
}

if ($json.status -ne "success") {
    $errCode = $json.error.code
    $errMsg = $json.error.message
    throw "Sightengine API 调用失败 [$errCode]: $errMsg"
}

$aiScore = $null
if ($null -ne $json.type -and $null -ne $json.type.ai_generated) {
    $aiScore = [double]$json.type.ai_generated
}
elseif ($null -ne $json.genai -and $null -ne $json.genai.probability) {
    $aiScore = [double]$json.genai.probability
}

$judgment = "不确定 (0.1 ~ 0.9)"
$statusEmoji = "🟡"
$colorTag = "#e3b341" # 黄色
if ($null -ne $aiScore) {
    if ($aiScore -ge 0.9) {
        $judgment = "AI 生成"
        $statusEmoji = "🤖"
        $colorTag = "#f85149" # 红色
    }
    elseif ($aiScore -le 0.1) {
        $judgment = "非 AI (真实拍摄)"
        $statusEmoji = "📷"
        $colorTag = "#2ea043" # 绿色
    }
}

# 构建 20 格进度条
$barLength = 20
$filledCount = 0
if ($null -ne $aiScore) {
    $filledCount = [math]::Round($aiScore * $barLength)
}
$emptyCount = $barLength - $filledCount
$progressBar = ("█" * $filledCount) + ("░" * $emptyCount)

$ops = if ($json.request -and $json.request.operations) { $json.request.operations } else { 5 }
$target = if ($ImagePath) { (Split-Path $ImagePath -Leaf) } else { $ImageUrl }

# 输出纯净 JSON，供调用方或用户直接美化解析
$resultObj = [PSCustomObject]@{
    Target       = $target
    AiScore      = $aiScore
    Percentage   = if ($null -ne $aiScore) { ("{0:P1}" -f $aiScore) } else { "N/A" }
    ProgressBar  = $progressBar
    Judgment     = $judgment
    StatusEmoji  = $statusEmoji
    ColorTag     = $colorTag
    Operations   = $ops
}

Write-Output ($resultObj | ConvertTo-Json -Compress)
