param(
    [string]$RepoPath = (Join-Path $env:USERPROFILE ".codex\skills"),
    [string]$RemoteUrl = "https://github.com/ghostltx/codex-skills.git",
    [string]$Message = "",
    [string[]]$SkillName = @(),
    [ValidateSet("Push", "Pull")]
    [string]$Mode = "Push",
    [switch]$Overwrite,
    [switch]$IncludeSyncSkillsGit,
    [string]$Branch = "",
    [string]$TagName = "",
    [switch]$ListTags,
    [string]$ReleaseTitle = "",
    [string]$ReleaseNotes = ""
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

function New-DefaultTagName {
    return "skills-v" + (Get-Date -Format "yyyyMMdd-HHmmss")
}

function Get-GitHubReleaseToken {
    if (-not [string]::IsNullOrWhiteSpace($env:GH_TOKEN)) {
        return $env:GH_TOKEN
    }
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
        return $env:GITHUB_TOKEN
    }
    return ""
}

function Test-CommandAvailable {
    param([string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-RemoteTags {
    $remoteTags = & git -C $RepoPath ls-remote --tags origin
    if ($LASTEXITCODE -ne 0) {
        throw "git ls-remote --tags origin failed with exit code $LASTEXITCODE"
    }

    return $remoteTags |
        Where-Object { $_ -match "refs/tags/" -and $_ -notmatch "\^\{\}$" } |
        ForEach-Object { ($_ -split "refs/tags/", 2)[1] } |
        Sort-Object -Descending
}

function Get-TagFetchRef {
    param([string]$Name)

    $safe = $Name -replace "[^A-Za-z0-9._/-]", "-"
    return "refs/codex-sync-tags/$safe"
}

function New-GitHubRelease {
    param(
        [string]$Name,
        [string]$Target,
        [string]$Title,
        [string]$Notes
    )

    if ([string]::IsNullOrWhiteSpace($Title)) {
        $Title = $Name
    }
    if ([string]::IsNullOrWhiteSpace($Notes)) {
        $Notes = "Codex skills snapshot for $Name."
    }

    if (Test-CommandAvailable -Name "gh") {
        & gh release view $Name --repo ghostltx/codex-skills *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Output "GitHub Release already exists for tag: $Name"
            return
        }

        & gh release create $Name --repo ghostltx/codex-skills --target $Target --title $Title --notes $Notes
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create GitHub Release for tag '$Name' with gh."
        }
        Write-Output "Created GitHub Release with gh for tag: $Name"
        return
    }

    $token = Get-GitHubReleaseToken
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw "Cannot create GitHub Release for tag '$Name': gh is unavailable and GH_TOKEN/GITHUB_TOKEN is not set."
    }

    $headers = @{
        Authorization = "Bearer $token"
        Accept = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }

    $existingUri = "https://api.github.com/repos/ghostltx/codex-skills/releases/tags/$([uri]::EscapeDataString($Name))"
    try {
        Invoke-RestMethod -Method Get -Uri $existingUri -Headers $headers | Out-Null
        Write-Output "GitHub Release already exists for tag: $Name"
        return
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -ne 404) {
            throw
        }
    }

    $body = @{
        tag_name = $Name
        target_commitish = $Target
        name = $Title
        body = $Notes
        draft = $false
        prerelease = $false
    } | ConvertTo-Json

    Invoke-RestMethod -Method Post -Uri "https://api.github.com/repos/ghostltx/codex-skills/releases" -Headers $headers -Body $body -ContentType "application/json" | Out-Null
    Write-Output "Created GitHub Release with GitHub API for tag: $Name"
}

function Copy-TrackedPathBackup {
    param(
        [string]$RelativePath,
        [string]$BackupRoot
    )

    $trackedFiles = & git -C $RepoPath ls-files -- $RelativePath
    foreach ($file in $trackedFiles) {
        $source = Join-Path $RepoPath $file
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            continue
        }

        $target = Join-Path $BackupRoot $file
        $targetDir = Split-Path -Parent $target
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
}

function Restore-TrackedPathBackup {
    param(
        [string]$RelativePath,
        [string]$BackupRoot
    )

    $sourceRoot = Join-Path $BackupRoot $RelativePath
    if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
        return
    }

    Copy-Item -LiteralPath $sourceRoot -Destination $RepoPath -Recurse -Force
    Invoke-Git @("add", "--", $RelativePath)
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
    $origin = $RemoteUrl
}

if ($origin.TrimEnd("/") -ne $RemoteUrl.TrimEnd("/")) {
    throw "Refusing to sync: origin is '$origin', expected '$RemoteUrl'. This shortcut is only for ghostltx/codex-skills."
}

Ensure-GitProxy

if ($ListTags) {
    $tags = Get-RemoteTags
    Write-Output "TAGS:"
    $tags | ForEach-Object { Write-Output $_ }
    return
}

if ([string]::IsNullOrWhiteSpace($Branch)) {
    $Branch = (& git -C $RepoPath branch --show-current).Trim()
    if ([string]::IsNullOrWhiteSpace($Branch)) {
        $Branch = "main"
    }
}

if ($Mode -eq "Pull") {
    Invoke-Git @("fetch", "origin", $Branch)

    if (-not [string]::IsNullOrWhiteSpace($TagName)) {
        $remoteTags = Get-RemoteTags
        if ($remoteTags -notcontains $TagName) {
            throw "Remote tag not found: $TagName"
        }

        $tagFetchRef = Get-TagFetchRef -Name $TagName
        Invoke-Git @("fetch", "origin", "+refs/tags/$($TagName):$tagFetchRef")
    }

    $pullTarget = if ([string]::IsNullOrWhiteSpace($TagName)) { "origin/$Branch" } else { $tagFetchRef }

    if ($Overwrite) {
        $dirty = (& git -C $RepoPath status --short)
        $backupDir = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-skills-sync-backup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

        if (-not [string]::IsNullOrWhiteSpace(($dirty -join "`n"))) {
            & git -C $RepoPath diff --binary > (Join-Path $backupDir "local-tracked-changes.patch")
            & git -C $RepoPath diff --cached --binary > (Join-Path $backupDir "local-staged-changes.patch")
            & git -C $RepoPath status --short > (Join-Path $backupDir "status-before-overwrite.txt")
        }

        if (-not $IncludeSyncSkillsGit) {
            Copy-TrackedPathBackup -RelativePath "sync-skills-git" -BackupRoot $backupDir
            Write-Output "Preserving local sync-skills-git during pull overwrite."
        }

        Invoke-Git @("reset", "--hard", $pullTarget)

        if (-not $IncludeSyncSkillsGit) {
            Restore-TrackedPathBackup -RelativePath "sync-skills-git" -BackupRoot $backupDir
        }

        Write-Output "Saved pull backup metadata to: $backupDir"
    } else {
        if ([string]::IsNullOrWhiteSpace($TagName)) {
            Invoke-Git @("pull", "--ff-only", "origin", $Branch)
        } else {
            Invoke-Git @("checkout", $pullTarget)
        }
    }

    $head = (& git -C $RepoPath log --oneline --decorate -1)
    $status = (& git -C $RepoPath status --short --branch)
    $remote = (& git -C $RepoPath remote -v)

    Write-Output ""
    Write-Output "MODE: Pull"
    Write-Output "OVERWRITE: $($Overwrite.IsPresent)"
    Write-Output "TAG: $TagName"
    Write-Output "INCLUDE_SYNC_SKILLS_GIT: $($IncludeSyncSkillsGit.IsPresent)"
    Write-Output "HEAD: $head"
    Write-Output "STATUS:"
    $status | ForEach-Object { Write-Output $_ }
    Write-Output "REMOTE:"
    $remote | ForEach-Object { Write-Output $_ }
    return
}

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

Invoke-Git @("push", "-u", "origin", $Branch)

if ([string]::IsNullOrWhiteSpace($TagName)) {
    $TagName = New-DefaultTagName
}

$headSha = (& git -C $RepoPath rev-parse HEAD).Trim()
$existingTag = (& git -C $RepoPath tag --list $TagName)
if ([string]::IsNullOrWhiteSpace(($existingTag -join "`n"))) {
    Invoke-Git @("tag", "-a", $TagName, "-m", "Codex skills snapshot $TagName", $headSha)
} else {
    $tagSha = (& git -C $RepoPath rev-list -n 1 $TagName).Trim()
    if ($tagSha -ne $headSha) {
        throw "Tag '$TagName' already exists at $tagSha, not current HEAD $headSha."
    }
    Write-Output "Tag already exists at current HEAD: $TagName"
}

Invoke-Git @("push", "origin", $TagName)
New-GitHubRelease -Name $TagName -Target $headSha -Title $ReleaseTitle -Notes $ReleaseNotes

$head = (& git -C $RepoPath log --oneline --decorate -1)
$status = (& git -C $RepoPath status --short --branch)
$remote = (& git -C $RepoPath remote -v)

Write-Output ""
Write-Output "MODE: Push"
Write-Output "TAG: $TagName"
Write-Output "HEAD: $head"
Write-Output "STATUS:"
$status | ForEach-Object { Write-Output $_ }
Write-Output "REMOTE:"
$remote | ForEach-Object { Write-Output $_ }
