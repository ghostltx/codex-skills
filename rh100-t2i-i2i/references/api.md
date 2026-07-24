# RH100 API reference

## Endpoints

- Text-to-image: `POST https://www.runninghub.cn/openapi/v2/rhart-image-g-2/text-to-image`
- Image-to-image: `POST https://www.runninghub.cn/openapi/v2/rhart-image-g-2/image-to-image`
- Query task: `POST https://www.runninghub.cn/openapi/v2/query`
- Upload: `POST https://www.runninghub.cn/openapi/v2/media/upload/binary`

Both G-2 generation endpoints accept `prompt`, `aspectRatio`, `resolution`, `instanceType`, and optional `webhookUrl`. Image-to-image additionally requires `imageUrls` with at most 10 images; each uploaded image is limited to 30 MB. The endpoint pages document defaults of `aspectRatio=16:9` and `resolution=1k`.

The fast-submit workflow does not open a browser, query task status, or download results. Report `https://www.runninghub.cn/call-api/bill-task` after submission, then ask the user whether to download. After confirmation, query each `taskId` and download all `results[].url` values. Uploaded media URLs expire after 1 day; generated result URLs expire after 24 hours.

Enterprise instance types are `default` (Standard) and `plus` (Plus). Omit `instanceType` for Lite auto-scheduling.
