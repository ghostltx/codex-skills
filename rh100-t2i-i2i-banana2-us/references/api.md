# RunningHub Nano Banana 2 US API reference

## User-provided API detail pages

- Text-to-image: `https://www.runninghub.ai/zh-cn/call-api/api-detail/2027192837726294017`
- Image-to-image: `https://www.runninghub.ai/zh-cn/call-api/api-detail/2027196343409463297`

The detail pages may require a signed-in RunningHub session. Keep these IDs as the user’s source of truth when the platform changes routing.

## Current public official-stable routes

- Text-to-image: `POST https://www.runninghub.ai/openapi/v2/rhart-image-n-g31-flash-official/text-to-image`
- Image-to-image: `POST https://www.runninghub.ai/openapi/v2/rhart-image-n-g31-flash-official/image-to-image`
- Query task: `POST https://www.runninghub.ai/openapi/v2/query`
- Upload local media: `POST https://www.runninghub.ai/openapi/v2/media/upload/binary`
- Task page: `https://www.runninghub.ai/call-api/bill-task`

## Authentication

Send `Authorization: Bearer <RUNNINGHUB_API_KEY_US>` and `Content-Type: application/json`. Model APIs require a RunningHub Enterprise-Shared API Key.

## Request bodies

Text-to-image:

```json
{
  "prompt": "...",
  "aspectRatio": "1:1",
  "resolution": "1k"
}
```

Image-to-image adds `imageUrls`:

```json
{
  "imageUrls": ["https://..."],
  "prompt": "...",
  "aspectRatio": "4:5",
  "resolution": "2k"
}
```

Supported output resolutions documented publicly are `1k`, `2k`, and `4k`; Nano Banana 2 supports up to 14 reference images for image editing. The API returns a task-shaped response containing `taskId`; query results only after the user explicitly confirms download.

## Public documentation

- [Nano Banana 2 text-to-image API](https://www.runninghub.cn/runninghub-api-doc-en/api-448184537)
- [Nano Banana 2 image-to-image API](https://www.runninghub.cn/runninghub-api-doc-en/api-448184501)
