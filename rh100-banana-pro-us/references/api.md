# RunningHub Banana PRO US API reference

## User-provided API detail pages

- Text-to-image: `https://www.runninghub.ai/zh-cn/call-api/api-detail/2004543847939751938`
- Composition image-to-image: `https://www.runninghub.ai/zh-cn/call-api/api-detail/2027661818379649025`

## Endpoint mapping

The first page is the Banana Pro text-to-image API:

`POST https://www.runninghub.ai/openapi/v2/rhart-image-n-pro-official/text-to-image`

The second page is the Nano Banana 2 official-stable image-to-image/composition API:

`POST https://www.runninghub.ai/openapi/v2/rhart-image-n-g31-flash-official/image-to-image`

This mixed mapping is intentional because the second user-provided detail page is published as Nano Banana 2 image-to-image, despite the requested skill name being Banana PRO.

## Shared endpoints

- Query: `POST https://www.runninghub.ai/openapi/v2/query`
- Upload: `POST https://www.runninghub.ai/openapi/v2/media/upload/binary`
- Task page: `https://www.runninghub.ai/call-api/bill-task`

## Authentication and bodies

Use `Authorization: Bearer <RUNNINGHUB_API_KEY_US>` and `Content-Type: application/json`.

Text-to-image body:

```json
{
  "prompt": "...",
  "aspectRatio": "4:5",
  "resolution": "2k"
}
```

Composition image-to-image body:

```json
{
  "imageUrls": ["https://..."],
  "prompt": "...",
  "aspectRatio": "4:5",
  "resolution": "2k"
}
```

The composition endpoint supports up to 14 reference images and returns a task-shaped response containing `taskId`.

## Public references

- [Nano Banana Pro text-to-image detail](https://www.runninghub.ai/call-api/api-detail/2015599191101071361)
- [Nano Banana Pro edit detail](https://www.runninghub.ai/call-api/api-detail/2004544343584849921)
- [User-provided composition API detail](https://www.runninghub.ai/call-api/api-detail/2027661818379649025)
