---
name: new-api-rim-gpt-image-2-only-1k
description: Generate images through the user's NewAPI endpoint using only the configured `「Rim」gpt-image-2` model at about 1K to 1.5MP output. Use when the user asks to generate images with NEW API, `「Rim」gpt-image-2`, NewAPI gpt-image-2 only-1k, docs.newapi.pro, or the local NewAPI image-generation setup; supports serial batch generation, model connectivity checks, and local output saving.
---

# NEW API 「Rim」gpt-image-2 only-1k

Use this skill to generate images through NewAPI's OpenAI-compatible image API and save the outputs locally.

## Local Model Notes

- `「Rim」gpt-image-2` is the configured default model for this local skill.
- Treat this platform as about 1.5 million pixels for normal image generation.
- Default square size: `1254x1254`.
- Do not request 2K or 4K output for normal generation. Only test larger sizes when the user explicitly asks for a capability check.
- For non-square images, compute dimensions from the requested aspect ratio with total pixels around 1.5MP.

Common 1.5MP sizes:

| Ratio | Portrait | Landscape |
| --- | --- | --- |
| `1:1` | `1254x1254` | `1254x1254` |
| `4:5` | `1123x1401` | `1401x1123` |
| `2:3` | `1025x1534` | `1534x1025` |
| `3:4` | `1090x1443` | `1443x1090` |
| `9:16` | `941x1670` | `1670x941` |
| `16:9` | `941x1670` | `1670x941` |

## Quick Start

1. Read `references/newapi-image-api.md` when you need endpoint details, request fields, response fields, or troubleshooting notes.
2. Load API configuration from `scripts/newapi-imagegen-env.ps1` when available, or require keys from `NEWAPI_API_KEYS`, `NEWAPI_API_KEY`, or `NEW_API_KEY`. Do not print the key.
3. Use `scripts/generate_image.py` for text-to-image generation whenever possible.
4. Use `scripts/edit_image.py` for image-to-image edits such as hair color changes or background style changes.
5. Run batch work serially. Do not launch 6 parallel image requests for `「Rim」gpt-image-2`.
6. Save outputs to the user's requested directory, otherwise use the current workspace or `./outputs/newapi-imagegen`.
7. Report the saved file paths and any validation gaps.

## Text-To-Image Workflow

Run:

```bash
.\scripts\newapi-imagegen-env.ps1
python scripts/generate_image.py ^
  --prompt "A clean product photo of ..." ^
  --size "1254x1254" ^
  --output-dir "./outputs/newapi-imagegen"
```

Use the user's NewAPI deployment base URL, not the documentation site, when they provide one. The script normalizes base URLs and calls `/v1/images/generations`.

Useful options:

- `--n`: number of images.
- `--quality`: pass through provider-supported values such as `standard`, `hd`, `low`, `medium`, or `high`.
- `--response-format`: `b64_json` or `url`; default `b64_json` is easiest to save reliably.
- `--api-key-env`: environment variable containing one key or multiple comma-separated keys.
- `--prompts-file`: one prompt per line; runs serially.
- `--batch-delay`: delay between prompts in batch mode; default `60` seconds.
- `--memory-overload-wait`: wait time after `system_memory_overloaded`; default `180` seconds.

## Batch And Concurrency

Use serial batch generation for this platform:

```bash
python scripts/generate_image.py ^
  --prompts-file "./prompts.txt" ^
  --batch-delay 60 ^
  --memory-overload-wait 180 ^
  --output-dir "./outputs/newapi-imagegen"
```

Do not run six image requests in parallel. Local tests with 6 immediate parallel requests and 6 staggered requests 10 seconds apart both failed with `system_memory_overloaded` while server memory was above the 90% threshold.

If `system_memory_overloaded` appears, pause and retry later instead of continuing to queue requests.

## Image Editing

The NewAPI OpenAI-compatible edit endpoint requires a PNG image. The public docs state the image must be square and under 4 MB, and edit output size should be `256x256`, `512x512`, or `1024x1024`.

Use:

```bash
python scripts/edit_image.py ^
  --image "./source.png" ^
  --prompts-file "./edit-prompts.txt" ^
  --size "1024x1024" ^
  --batch-delay 60 ^
  --memory-overload-wait 180 ^
  --output-dir "./outputs/newapi-image-edits"
```

For edits, explicitly tell the model to preserve the person's face, pose, clothing, camera angle, framing, lighting character, and original composition unless the user asks otherwise.

## Model Discovery

When the user is unsure which image model is enabled on their NewAPI instance, run:

```bash
.\scripts\newapi-imagegen-env.ps1
python scripts/generate_image.py --list-models
```

Then choose a likely image-capable model from the returned list. NewAPI channels may expose different model names depending on upstream configuration, so avoid hardcoding one model as universal.

## Guardrails

- Never invent credentials. Ask for the key only if no environment variable, env ps1 file, or explicit key exists.
- Avoid logging request headers or full exception objects that may include credentials.
- Prefer `b64_json` for deterministic local saves; use `url` only when the provider requires it.
- If a model rejects `size`, `quality`, or `response_format`, retry with fewer optional fields before declaring failure.
- For image editing or image-to-image, consult the reference first; this skill's script currently implements text-to-image and model listing.
