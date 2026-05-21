---
name: sync-skills-git
description: Commit, push, pull, and overwrite-sync the user's personal Codex skills repository. Use only for ghostltx/codex-skills when the user asks to upload, save, git, commit, push, sync, back up, download, pull, restore, overwrite, or sync skill changes across company computer, GitHub, and local computer, especially phrases like "同步", "上传 skills", "提交 skill", "git 一下 skill", "保存我的 skill", "更新了 skill 帮我上传", "拉取", "从 GitHub 下载 skills", "拉取覆盖本机 skills", or "同步公司电脑的 skill".
---

# Sync Skills Git

## Default Repository

Operate only on `$env:USERPROFILE\.codex\skills` as the local checkout of `ghostltx/codex-skills`.

The expected remote is:

```text
https://github.com/ghostltx/codex-skills.git
```

This shorthand rule applies only to the `ghostltx/codex-skills` repository:

- When the user says `同步`, treat it as "sync local personal skills to the GitHub repository": first include local personal skill folders in the repository allowlist, then upload/push local personal skill changes to GitHub, create the next `v1.xx` version Tag, push the Tag, and create a GitHub Release from that Tag.
- When the user says `拉取`, list available version Tags first, ask the user which Tag to download, then overwrite tracked local personal skill files from that Tag.
- Do not apply this shorthand to any other repository or normal project workspace.

## Push Workflow

1. Check repository status and remote.
2. If the remote is missing, add `origin` using the expected remote URL.
3. If `origin` points anywhere other than `https://github.com/ghostltx/codex-skills.git`, stop.
4. If Git has no local proxy but Windows system proxy is enabled, copy the Windows proxy into the repository's `http.proxy` and `https.proxy` settings before network operations.
5. Before staging, update the repository root `.gitignore` allowlist for local personal skill folders that should sync. For plain `同步`, do this automatically for immediate child folders that contain `SKILL.md` and are not hidden/system/cache folders; if the user names a specific new skill, pass `-SkillName` for that skill explicitly.
6. Re-check `git status --short --ignored` after allowlist updates so newly included skill files are visible before staging.
7. Stage only repository-managed skill files and Git metadata.
8. Commit when there are staged changes.
9. Push the current branch to `origin`.
10. Create a version Tag for the pushed HEAD. If the user gave a Tag name, pass it with `-TagName`; otherwise let the script create the next `v1.xx` Tag after the highest existing version Tag.
11. Push the Tag to `origin`.
12. Create a GitHub Release based on that Tag. The script uses `gh` when available, otherwise `GH_TOKEN`, `GITHUB_TOKEN`, or the existing Git Credential Manager token with the GitHub API.
13. Report the commit hash, branch, Tag, Release result, remote, and whether the working tree is clean.

Use `scripts/sync-skills-git.ps1` for the normal upload path. Pass `-Message` when the user provides a commit message; otherwise write a concise intent-based message from the changed files.
If the user provides a Tag, pass `-TagName`. If the user provides Release title or notes, pass `-ReleaseTitle` and `-ReleaseNotes`.

## Pull / Overwrite Workflow

Use this when the user wants to download skills from GitHub, restore the company computer version, overwrite this computer, or synchronize GitHub to the current machine.

1. Check repository status and remote.
2. Ensure `origin` points to `https://github.com/ghostltx/codex-skills.git`; stop if it points anywhere else.
3. Copy Windows system proxy into repository-local Git proxy settings when needed.
4. Fetch `origin`; list Tags from the remote repository so stale local Tags cannot block version selection.
5. If the user says `拉取`, first run `scripts/sync-skills-git.ps1 -ListTags`, show the available Tags, and ask the user to choose exactly one Tag. Do not choose a Tag silently unless the user explicitly named one.
6. Download from GitHub and overwrite tracked local personal skill files from the chosen Tag with `-Mode Pull -Overwrite -TagName <tag>`.
7. Report the branch, selected Tag, remote, HEAD commit, and working tree status.

Important: overwrite mode is allowed only for this personal skills repository when the user explicitly asks to pull/overwrite local skills from GitHub. It resets tracked files to the selected GitHub Tag state but does not delete unrelated untracked local skill folders unless the user separately asks for an exact clean mirror.

## Guardrails

- Do not delete files or directories except tracked files reset by the explicit `拉取` overwrite workflow.
- Do not add installed system/OMX skills unless the user explicitly names them.
- Do not commit credentials, cache folders, logs, generated images, sessions, or SQLite files.
- Preserve the repository's existing `.gitignore` allowlist pattern.
- Prefer repository-local Git proxy settings copied from Windows system proxy, so browser-accessible GitHub also works for Git push/pull.
- If authentication fails during push or pull, report the exact blocker and leave local files intact.
- If GitHub Release creation fails because `gh`, `GH_TOKEN`, and `GITHUB_TOKEN` are unavailable, report that the commit and Tag push status separately from the Release blocker.
- Never pull a Tag without showing available Tags and asking the user to select one, unless the user already provided an explicit Tag in the same request.

## Common Commands

Commit and push with an inferred message:

```powershell
& "$env:USERPROFILE\.codex\skills\sync-skills-git\scripts\sync-skills-git.ps1"
```

Commit, push, Tag, and create a Release with an explicit Tag:

```powershell
& "$env:USERPROFILE\.codex\skills\sync-skills-git\scripts\sync-skills-git.ps1" -TagName "skills-v20260518-120000"
```

Default plain sync creates the next version Tag such as `v1.06`, not a timestamp Tag.

Commit and push with a supplied message:

```powershell
& "$env:USERPROFILE\.codex\skills\sync-skills-git\scripts\sync-skills-git.ps1" -Message "Update Amazon image skills"
```

Include a newly created skill folder in the allowlist:

```powershell
& "$env:USERPROFILE\.codex\skills\sync-skills-git\scripts\sync-skills-git.ps1" -SkillName "my-new-skill"
```

Plain `同步` also runs automatic allowlist discovery for immediate local skill folders:

```powershell
& "$env:USERPROFILE\.codex\skills\sync-skills-git\scripts\sync-skills-git.ps1"
```

Download from GitHub and overwrite tracked local skill files:

```powershell
& "$env:USERPROFILE\.codex\skills\sync-skills-git\scripts\sync-skills-git.ps1" -ListTags
& "$env:USERPROFILE\.codex\skills\sync-skills-git\scripts\sync-skills-git.ps1" -Mode Pull -Overwrite -TagName "skills-v20260518-120000"
```
