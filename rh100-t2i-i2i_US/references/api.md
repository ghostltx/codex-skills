# RH100 US API reference

## Endpoints

- Text-to-image (Sunburst): `POST https://www.runninghub.ai/openapi/v2/rhart-image-g-2.5-official-token/sunburst/text-to-image`
- High-precision image edit (Sunburst): `POST https://www.runninghub.ai/openapi/v2/rhart-image-g-2.5-official-token/sunburst/edit`
- High-speed image edit (Flare): `POST https://www.runninghub.ai/openapi/v2/rhart-image-g-2.5-official-token/flare/edit`
- Query task: `POST https://www.runninghub.ai/openapi/v2/query`
- Upload: `POST https://www.runninghub.ai/openapi/v2/media/upload/binary`
- Task page: `https://www.runninghub.ai/call-api/bill-task`

All three endpoints accept `prompt`, `aspectRatio`, `resolution`, `background`, `quality`, `outputFormat`, and optional `webhookUrl`.
Both edit endpoints additionally require `imageUrls` with 1-16 `JPG`, `JPEG`, `PNG`, or `WEBP` images. `background` is `auto`, `transparent`, or `opaque`; `quality` is `auto`, `low`, `medium`, `high`, `xhigh`, or `max`; `outputFormat` is `jpeg`, `png`, or `webp`.

Authentication uses `Authorization: Bearer <RUNNINGHUB_API_KEY_US>`.

The fast-submit workflow does not query task status or download results. Open the task page after submission, then ask the user whether to download. After confirmation, query each `taskId` and download all `results[].url` values.

Configured model route documents:

- Text-to-image / Sunburst: `https://www.runninghub.ai/zh-cn/call-api/api-detail/2133100000000800375`
- High-precision image edit / Sunburst: `https://www.runninghub.ai/zh-cn/call-api/api-detail/2133100000000800376`
- High-speed image edit / Flare: `https://www.runninghub.ai/zh-cn/call-api/api-detail/2133100000000800378`
