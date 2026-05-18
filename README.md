# Personal Codex Skills

This repository stores personal Codex skills and version tags for rollback.

## Version Notes

### v1.03

`v1.03` upgrades the personal skills sync workflow with versioned releases:

- Upload/sync now creates a version Tag, pushes it to GitHub, and creates a GitHub Release from that Tag.
- Download/pull now lists remote Tags first and requires selecting a Tag version before overwriting tracked local skill files.
- Added script options:
  - `-TagName` for explicit version Tags.
  - `-ListTags` for remote Tag discovery.
  - `-ReleaseTitle` and `-ReleaseNotes` for Release metadata.
- Release creation uses `gh` when available, otherwise falls back to the GitHub API through `GH_TOKEN` or `GITHUB_TOKEN`.
- Tag pulls use isolated remote Tag refs so stale local Tags cannot block version selection.

In short, `v1.03` makes skills sync version-aware: uploads become tagged releases, and downloads become deliberate version restores.

### v1.01

`v1.01` is based on `v1.0` and contains one update commit:

- Commit: `cb3b57c` - `Update personal skills for v1.01`
- Changed files:
  - `amazon-plus-1.0/SKILL.md`
  - `fantui/SKILL.md`
- Diff size:
  - `41` insertions
  - `12` deletions

#### amazon-plus-1.0

- Expanded generation routing from two modes to four modes:
  - `A` = built-in Image Gen
  - `B` = RunningHub RH-GPT-IMAGE-2-I2I
  - `C` = ZZ gpt-image-2 / T8Star
  - `D` = RunningHub GPT Image 2 Official Stable
- Added explicit support for `ZZ gpt-image-2` / `T8Star`.
- Added explicit support for RunningHub GPT Image 2 Official Stable.
- Updated resolution routing:
  - `1K` routes to Mode A
  - `2K` routes to Mode B unless Mode D is explicitly selected
  - `4K` routes to Mode D
  - `ZZ`, `gpt-image-2`, or `T8Star` routes to Mode C

#### fantui

- Changed the default detail-page image ratio from `3:4` to `1:1`.
- Added a required `【亚马逊5大点】` section.
- Requires the 10-screen detail-page plan to echo and visualize the Amazon 5 bullet points.
- Strengthened line-art constraint wording so prompts must preserve product silhouette, proportions, and physical volume.

In short, `v1.01` improves Amazon image-generation routing across multiple providers and makes Fantui output better aligned with Amazon square images and listing bullet-point logic.

### v1.0

Baseline uploaded version before the `v1.01` updates.
