param(
    [string]$RepoPath = "C:\Users\Administrator\.codex\skills",
    [string]$RemoteUrl = "https://github.com/ghostltx/codex-skills.git",
    [string]$Message = "",
    [string[]]$SkillName = @()
)

$ErrorActionPreference = "Stop"

function Invoke-Git {
    param([string[]]$Arguments)
    & git -C $RepoPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

function Add-AllowlistEntry {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return
    }

    $skillPath = Join-Path $RepoPath $Name
    if (-not (Test-Path -LiteralPath $skillPath -PathType Container)) {
        throw "Skill folder not found: $skillPath"
    }

    $ignorePath = Join-Path $RepoPath ".gitignore"
    $content = Get-Content -LiteralPath $ignorePath -Raw
    $folderRule = "!$Name/"
    $childrenRule = "!$Name/**"

    if ($content -notmatch [regex]::Escape($folderRule)) {
        Add-Content -LiteralPath $ignorePath -Value $folderRule
    }
    if ($content -notmatch [regex]::Escape($childrenRule)) {
        Add-Content -LiteralPath $ignorePath -Value $childrenRule
    }
}

function Get-WindowsSystemProxy {
    $settingsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $settings = Get-ItemProperty -LiteralPath $settingsPath -ErrorAction SilentlyContinue
    if ($null -eq $settings -or [int]$settings.ProxyEnable -ne 1) {
        return ""
    }

    $proxyServer = [string]$settings.ProxyServer
    if ([string]::IsNullOrWhiteSpace($proxyServer)) {
        return ""
    }

    $candidate = $proxyServer
    if ($proxyServer -match "=") {
        $entry = ($proxyServer -split ";") |
            Where-Object { $_ -match "^(https?|all)=" } |
            Select-Object -First 1
        if ([string]::IsNullOrWhiteSpace($entry)) {
            return ""
        }
        $candidate = ($entry -split "=", 2)[1]
    }

    if ($candidate -notmatch "^[a-zA-Z][a-zA-Z0-9+.-]*://") {
        $candidate = "http://$candidate"
    }

    return $candidate
}

function Ensure-GitProxy {
    $existing = (& git -C $RepoPath config --get http.proxy 2>$null)
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($existing)) {
        Write-Output "Using existing Git proxy: $existing"
        return
    }

    $systemProxy = Get-WindowsSystemProxy
    if ([string]::IsNullOrWhiteSpace($systemProxy)) {
        Write-Output "No Git proxy configured and no Windows system proxy detected."
        return
    }

    Invoke-Git @("config", "http.proxy", $systemProxy)
    Invoke-Git @("config", "https.proxy", $systemProxy)
    Write-Output "Configured Git proxy from Windows system proxy: $systemProxy"
}

if (-not (Test-Path -LiteralPath (Join-Path $RepoPath ".git") -PathType Container)) {
    throw "Not a Git repository: $RepoPath"
}

foreach ($name in $SkillName) {
    Add-AllowlistEntry -Name $name
}

$origin = (& git -C $RepoPath remote get-url origin 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($origin)) {
    Invoke-Git @("remote", "add", "origin", $RemoteUrl)
}

Ensure-GitProxy

Invoke-Git @("add", ".")

$cached = (& git -C $RepoPath diff --cached --name-only)
if ([string]::IsNullOrWhiteSpace(($cached -join "`n"))) {
    Write-Output "No staged changes to commit."
} else {
    if ([string]::IsNullOrWhiteSpace($Message)) {
        $changedDirs = $cached |
            Where-Object { $_ -notmatch "^\." } |
            ForEach-Object { ($_ -split "/")[0] } |
            Sort-Object -Unique

        if ($changedDirs.Count -eq 0) {
            $Message = "Maintain skills repository metadata"
        } elseif ($changedDirs.Count -le 3) {
            $Message = "Update " + ($changedDirs -join ", ") + " skills"
        } else {
            $Message = "Update personal Codex skills"
        }
    }

    Invoke-Git @(
        "commit",
        "-m", $Message,
        "-m", "Constraint: Preserve personal Codex skill changes for reuse across environments. Confidence: high Scope-risk: narrow Directive: Keep generated/system skills out of this repository unless explicitly requested. Tested: git status and staged file list were checked by the sync script."
    )
}

$branch = (& git -C $RepoPath branch --show-current).Trim()
if ([string]::IsNullOrWhiteSpace($branch)) {
    throw "Could not determine current branch."
}

Invoke-Git @("push", "-u", "origin", $branch)

$head = (& git -C $RepoPath log --oneline --decorate -1)
$status = (& git -C $RepoPath status --short --branch)
$remote = (& git -C $RepoPath remote -v)

Write-Output ""
Write-Output "HEAD: $head"
Write-Output "STATUS:"
$status | ForEach-Object { Write-Output $_ }
Write-Output "REMOTE:"
$remote | ForEach-Object { Write-Output $_ }
