# NewAPI Image API Reference

Source reviewed: https://docs.newapi.pro/zh/docs

NewAPI exposes OpenAI-compatible API routes. For image generation, call:

`POST {base_url}/v1/images/generations`

For image editing, call:

`POST {base_url}/v1/images/edits`

## Authentication

Send an API token with Bearer auth:

`Authorization: Bearer <NEWAPI_API_KEY>`

Also send `Content-Type: application/json`.

## Request Body

Common fields for `/v1/images/generations`:

- `model`: image generation model available in the NewAPI instance.
- `prompt`: required text prompt.
- `n`: number of images to generate.
- `size`: image size such as `1024x1024`; support depends on model and channel.
- `response_format`: `b64_json`, `url`, or omit/auto depending on model support.
- `quality`: optional; model-dependent.
- `style`: optional; model-dependent.
- `background`: optional; `gpt-image-1` supports transparent, opaque, or auto-style background choices depending on channel translation.
- `moderation`: optional; `gpt-image-1` content moderation level, model-dependent.
- `output_format`: optional; use only when the selected model/channel documents support it.
- `user`: optional user identifier.

Only include optional fields when the user asks or the selected model supports them. If a request fails because a model does not support a parameter, remove that parameter and retry once.

## Response Handling

The response normally contains `data`, an array of generated images. Each item may include:

- `b64_json`: base64 image data to decode and save locally.
- `url`: remote image URL to download.
- `revised_prompt`: model-adjusted prompt metadata.

Always save a metadata JSON file beside the images with the sanitized request, response metadata, and output paths. Do not store the API key.

## Image Edit Request

The edit endpoint uses `multipart/form-data`.

Common fields:

- `image`: required PNG file. Public docs specify valid PNG, square, under 4 MB.
- `prompt`: required edit instruction, max 1000 characters in the public docs.
- `model`: selected image edit model.
- `n`: number of images, 1-10.
- `size`: public docs list `256x256`, `512x512`, or `1024x1024`.
- `response_format`: `url` or `b64_json`.

## Environment Variables

- `NEWAPI_API_KEYS`: preferred; one key or multiple comma-separated keys. The script tries the next key if auth/quota fails.
- `NEWAPI_API_KEY`: fallback for a single key.
- `NEWAPI_BASE_URL`: optional base URL override.
- `NEWAPI_IMAGE_MODEL`: optional model override.

This local skill defaults to `http://64.186.244.43:12001` and model `「Rim」gpt-image-2`.

## Local Test Notes

- `「Rim」gpt-image-2` is the default model.
- Treat this platform as about 1.5MP for normal image generation.
- Default square size is `1254x1254`.
- For non-square images, compute dimensions from the requested aspect ratio with total pixels around 1.5MP.
- Common tested/requested sizes: `1254x1254`, `1123x1401`, `1025x1534`, `1090x1443`, `941x1670`, `1670x941`.
- User-provided note on 2026-05-15: this platform/model should not be treated as 2K-capable for normal work.
- Batch/concurrency note: use serial generation. Six parallel requests and six 10-second-staggered requests failed with `system_memory_overloaded` when server memory was around 92%, above the 90% threshold. Use `--prompts-file`, `--batch-delay 60`, and `--memory-overload-wait 180` for batch work.

## Local Model Matrix Test, 2026-05-15

Prompt used: simple red apple product photo. The script recorded both requested size and actual PNG pixel size.

| Model | 1K request | 2K request | 4K request | Notes |
| --- | --- | --- | --- | --- |
| `gpt-image-2` | Failed | Failed | Failed | No available channel for unprefixed model. |
| `「AZ」gpt-image-2` | Failed | Failed | Failed | No available channel under GPT-Azure group. |
| `「CC」gpt-image-2` | Failed, 502 | OK, actual `2048x2048` | Failed, 502 | 2K works; 1K/4K unstable or unsupported in this run. |
| `「CS」gpt-image-2` | OK, actual `1254x1254` | OK, actual `1254x1254` | OK, actual `1254x1254` | Requests succeed but output is capped/downsampled around 1.25K. |
| `「CX」gpt-image-2` | Failed, 502 | OK, actual `2048x2048` | Failed, 502 | 2K works; 1K/4K unstable or unsupported in this run. |
| `「OP」gpt-5.4-image-2` | Failed | Failed | Failed | `invalid encrypted subpath`. |
| `「Rim」gpt-image-2` | OK, actual `1254x1254` | OK, actual `1254x1254` | OK, actual `1024x1024` | Requests may succeed but not at requested 2K/4K resolution. |
| `「XJ」gpt-image-2` | OK, actual `1024x1024` | OK, actual `2048x2048` | Failed | 4K rejected: longest edge must be <= 3840. |
| `「YQ」gpt-image-2` | OK, actual `1254x1254` | Failed, 500 | Failed, 500 | Only 1K-class output worked in this run. |
