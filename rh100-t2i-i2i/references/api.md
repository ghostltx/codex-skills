# RH100 API reference

## Endpoints

- Text-to-image: `POST https://www.runninghub.cn/openapi/v2/rhart-image-n-g31-flash/text-to-image`
- Image-to-image: `POST https://www.runninghub.cn/openapi/v2/rhart-image-n-g31-flash/image-to-image`
- Query task: `POST https://www.runninghub.cn/openapi/v2/query`
- Upload: `POST https://www.runninghub.cn/openapi/v2/media/upload/binary`

Both generation endpoints accept `prompt`, `aspectRatio`, `resolution`, `instanceType`, and optional `webhookUrl`. Image-to-image additionally requires `imageUrls` with at most 10 images; each uploaded image is limited to 30 MB.

The fast-submit workflow does not query task status or download results. Open `https://www.runninghub.cn/call-api/bill-task` after submission, then ask the user whether to download. After confirmation, query each `taskId` and download all `results[].url` values. Uploaded media URLs expire after 1 day; generated result URLs expire after 24 hours.

Enterprise instance types are `default` (Standard) and `plus` (Plus). Omit `instanceType` for Lite auto-scheduling.
