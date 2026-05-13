param(
    [string]$DefaultChoice = ""
)

$valid = @("A", "B", "C", "D")
$default = $DefaultChoice.Trim().ToUpper()
if ($default -and -not ($valid -contains $default)) {
    $default = ""
}

Write-Host "请选择生图方式（单选）："
Write-Host "A: 内置 Image Gen - (1K-free) Official Stable"
Write-Host "B: RunningHub RH I2I - (2K-0.04/pic)"
Write-Host "C: ZZ gpt-image-2 - (2K-0.04/pic)"
Write-Host "D: RunningHub GPT Image 2 Official Stable - (2K-0.93/pic & 4K-1.37/pic)"
if ($default) {
    Write-Host "直接输入 A/B/C/D，回车默认 [$default]。"
} else {
    Write-Host "直接输入 A/B/C/D。"
}

while ($true) {
    $inputValue = Read-Host "你的选择"
    if (-not $inputValue -and $default) {
        $choice = $default
    } else {
        $choice = $inputValue.Trim().ToUpper()
    }

    if ($valid -contains $choice) {
        Write-Output $choice
        exit 0
    }
    Write-Host "输入无效，请只输入 A、B、C 或 D。"
}
