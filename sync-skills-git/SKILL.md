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

- When the user says `同步`, upload/push local personal skill changes to GitHub.
- When the user says `拉取`, download from GitHub and overwrite tracked local personal skill files.
- Do not apply this shorthand to any other repository or normal project workspace.

## Push Workflow

1. Check repository status and remote.
2. If the remote is missing, add `origin` using the expected remote URL.
3. If `origin` points anywhere other than `https://github.com/ghostltx/codex-skills.git`, stop.
4. If Git has no local proxy but Windows system proxy is enabled, copy the Windows proxy into the repository's `http.proxy` and `https.proxy` settings before network operations.
5. If the user mentions a newly created skill that is not tracked, update the repository root `.gitignore` allowlist for that skill before staging.
6. Stage only repository-managed skill files and Git metadata.
7. Commit when there are staged changes.
8. Push the current branch to `origin`.
9. Report the commit hash, branch, remote, and whether the working tree is clean.

Use `scripts/sync-skills-git.ps1` for the normal upload path. Pass `-Message` when the user provides a commit message; otherwise write a concise intent-based message from the changed files.

## Pull / Overwrite Workflow

Use this when the user wants to download skills from GitHub, restore the company computer version, overwrite this computer, or synchronize GitHub to the current machine.

1. Check repository status and remote.
2. Ensure `origin` points to `https://github.com/ghostltx/codex-skills.git`; stop if it points anywhere else.
3. Copy Windows system proxy into repository-local Git proxy settings when needed.
4. Fetch `origin`.
5. If the user says `拉取`, download from GitHub and overwrite tracked local personal skill files with `-Mode Pull -Overwrite`.
6. Report the branch, remote, HEAD commit, and working tree status.

Important: overwrite mode is allowed only for this personal skills repository when the user explicitly asks to pull/overwrite local skills from GitHub. It resets tracked files to GitHub state but does not delete unrelated untracked local skill folders unless the user separately asks for an exact clean mirror.

## Guardrails

- Do not delete files or directories except tracked files reset by the explicit `拉取` overwrite workflow.
- Do not add installed system/OMX skills unless the user explicitly names them.
- Do not commit credentials, cache folders, logs, generated images, sessions, or SQLite files.
- Preserve the repository's existing `.gitignore` allowlist pattern.
- Prefer repository-local Git proxy settings copied from Windows system proxy, so browser-accessible GitHub also works for Git push/pull.
- If authentication fails during push or pull, report the exact blocker and leave local files intact.

## Common Commands

Commit and push with an inferred message:

```powershell
& "$env:USERPROFILE\.codex\skills\sync-skills-git\scripts\sync-skills-git.ps1"
```

Commit and push with a supplied message:

```powershell
& "$env:USERPROFILE\.codex\skills\sync-skills-git\scripts\sync-skills-git.ps1" -Message "Update Amazon image skills"
```

Include a newly created skill folder in the allowlist:

```powershell
& "$env:USERPROFILE\.codex\skills\sync-skills-git\scripts\sync-skills-git.ps1" -SkillName "my-new-skill"
```

Download from GitHub and overwrite tracked local skill files:

```powershell
& "$env:USERPROFILE\.codex\skills\sync-skills-git\scripts\sync-skills-git.ps1" -Mode Pull -Overwrite
```
