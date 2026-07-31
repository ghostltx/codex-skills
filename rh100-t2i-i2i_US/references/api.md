# RH100 US API reference

## Endpoints

- Text-to-image: `POST https://www.runninghub.ai/openapi/v2/rhart-image-g-2/text-to-image`
- Image-to-image: `POST https://www.runninghub.ai/openapi/v2/rhart-image-g-2/image-to-image`
- Query task: `POST https://www.runninghub.ai/openapi/v2/query`
- Upload: `POST https://www.runninghub.ai/openapi/v2/media/upload/binary`
- Task page: `https://www.runninghub.ai/call-api/bill-task`

Text-to-image accepts `prompt`, `aspectRatio`, `resolution`, `instanceType`, and optional `webhookUrl`.
Image-to-image accepts the same fields and additionally requires `imageUrls` with at most 10 images.

Authentication uses `Authorization: Bearer <RUNNINGHUB_API_KEY_US>`.

The fast-submit workflow does not query task status or download results. Open the task page after submission, then ask the user whether to download. After confirmation, query each `taskId` and download all `results[].url` values.

Configured model route documents:

- Text-to-image: `https://www.runninghub.ai/call-api/api-detail/2046514150500524033`
- Image-to-image: `https://www.runninghub.ai/call-api/api-detail/2046503667076751361`
