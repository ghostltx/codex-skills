param(
    [string]$DefaultChoice = ""
)

$valid = @("A", "B", "C", "D")
$default = $DefaultChoice.Trim().ToUpper()
if ($default -and -not ($valid -contains $default)) {
    $default = ""
}

Write-Host "Select generation mode (single choice):"
Write-Host "A: Image Gen - (1K-free) Official Stable"
Write-Host "B: RunningHub RH I2I - (2K-0.04/pic)"
Write-Host "C: RunningHub API - (1K/2K-0.16/pic , 100-Connection)"
Write-Host "D: RunningHub GPT Image 2 Official Stable - (2K-0.93/pic and 4K-1.37/pic)"
if ($default) {
    Write-Host "Enter A/B/C/D, or press Enter for [$default]."
} else {
    Write-Host "Enter A/B/C/D."
}

while ($true) {
    $inputValue = Read-Host "Choice"
    if (-not $inputValue -and $default) {
        $choice = $default
    } else {
        $choice = $inputValue.Trim().ToUpper()
    }

    if ($valid -contains $choice) {
        Write-Output $choice
        exit 0
    }

    Write-Host "Invalid input. Enter A, B, C, or D only."
}
