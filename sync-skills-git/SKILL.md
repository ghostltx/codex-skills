---
name: sync-skills-git
description: Commit and push the user's personal Codex skills repository. Use when the user asks to upload, save, git, commit, push, sync, back up, or pull/save skill changes, especially phrases like "上传 skills", "提交 skill", "git 一下 skill", "保存我的 skill", or "更新了 skill 帮我上传".
---

# Sync Skills Git

## Default Repository

Operate on `C:\Users\Administrator\.codex\skills` unless the user explicitly names another skills repository.

The expected remote is:

```text
https://github.com/ghostltx/codex-skills.git
```

## Workflow

1. Check repository status and remote.
2. If the remote is missing, add `origin` using the expected remote URL.
3. If Git has no local proxy but Windows system proxy is enabled, copy the Windows proxy into the repository's `http.proxy` and `https.proxy` settings before network operations.
4. If the user mentions a newly created skill that is not tracked, update the repository root `.gitignore` allowlist for that skill before staging.
5. Stage only repository-managed skill files and Git metadata.
6. Commit when there are staged changes.
7. Push the current branch to `origin`.
8. Report the commit hash, branch, remote, and whether the working tree is clean.

Use `scripts/sync-skills-git.ps1` for the normal path. Pass `-Message` when the user provides a commit message; otherwise write a concise intent-based message from the changed files.

## Guardrails

- Do not delete files or directories.
- Do not add installed system/OMX skills unless the user explicitly names them.
- Do not commit credentials, cache folders, logs, generated images, sessions, or SQLite files.
- Preserve the repository's existing `.gitignore` allowlist pattern.
- Prefer repository-local Git proxy settings copied from Windows system proxy, so browser-accessible GitHub also works for Git push/pull.
- If authentication fails during push, report the exact blocker and leave the local commit intact.

## Common Commands

Commit and push with an inferred message:

```powershell
C:\Users\Administrator\.codex\skills\sync-skills-git\scripts\sync-skills-git.ps1
```

Commit and push with a supplied message:

```powershell
C:\Users\Administrator\.codex\skills\sync-skills-git\scripts\sync-skills-git.ps1 -Message "Update Amazon image skills"
```

Include a newly created skill folder in the allowlist:

```powershell
C:\Users\Administrator\.codex\skills\sync-skills-git\scripts\sync-skills-git.ps1 -SkillName "my-new-skill"
```
