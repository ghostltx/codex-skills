# RH100 RunningHub API Reference

## Endpoint

Submit:

```http
POST https://www.runninghub.cn/openapi/v2/rhart-image-n-g31-flash/image-to-image
```

Query:

```http
POST https://www.runninghub.cn/openapi/v2/query
```

Upload:

```http
POST https://www.runninghub.cn/openapi/v2/media/upload/binary
```

## Auth

```http
Authorization: Bearer ${RUNNINGHUB_API_KEY}
Content-Type: application/json
```

## Submit Body

```json
{
  "imageUrls": ["https://example.com/image.png"],
  "prompt": "将这张线稿转换为明代水墨武侠风格的精细彩图。",
  "aspectRatio": "9:16",
  "resolution": "1k",
  "instanceType": "default",
  "webhookUrl": "https://example.com/webhook"
}
```

Fields:

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `imageUrls` | `List(String)` | yes | Max 10 images; each max 30 MB; public URL or supported Data URI |
| `prompt` | `String` | yes | 1 to 20000 characters |
| `aspectRatio` | `String` | no | See enum below |
| `resolution` | `String` | yes | `1k`, `2k`, `4k` |
| `instanceType` | `String` | enterprise shared | `default` for Standard, `plus` for Plus |
| `webhookUrl` | `String` | no | Receives task end POST callback |

Aspect ratio enum:

```text
1:1, 16:9, 9:16, 4:3, 3:4, 3:2, 2:3, 5:4, 4:5,
21:9, 1:4, 4:1, 1:8, 8:1
```

## Submit Response

```json
{
  "taskId": "2013508786110730241",
  "status": "RUNNING",
  "errorCode": "",
  "errorMessage": "",
  "results": null,
  "clientId": "f828b9af25161bc066ef152db7b29ccc",
  "promptTips": "{\"result\": true, \"error\": null, \"outputs_to_execute\": [\"4\"], \"node_errors\": {}}"
}
```

`taskId` is used for polling. Common statuses: `QUEUED`, `RUNNING`, `SUCCESS`, `FAILED`.

## Query Body

```json
{
  "taskId": "2013508786110730241"
}
```

## Success Response

```json
{
  "taskId": "2013508786110730241",
  "status": "SUCCESS",
  "errorCode": "",
  "errorMessage": "",
  "failedReason": {},
  "usage": {
    "consumeMoney": null,
    "consumeCoins": null,
    "taskCostTime": "0",
    "thirdPartyConsumeMoney": null
  },
  "results": [
    {
      "url": "https://example.com/output.png",
      "nodeId": "2",
      "outputType": "png",
      "text": null
    }
  ],
  "clientId": "",
  "promptTips": ""
}
```

`results[].url` expires after 24 hours. Download or transfer it immediately.

## Upload

Use multipart form field `file`.

```powershell
curl.exe --location --request POST "https://www.runninghub.cn/openapi/v2/media/upload/binary" `
  --header "Authorization: Bearer $env:RUNNINGHUB_API_KEY" `
  --form "file=@C:\path\to\image.png"
```

Response:

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "type": "image",
    "download_url": "xxxx.png",
    "fileName": "openapi/xxxx.png",
    "size": "3490"
  }
}
```

The uploaded URL expires after 1 day.

## Webhook

If `webhookUrl` is provided, RunningHub sends a POST when the task finishes:

```json
{
  "event": "TASK_END",
  "eventData": {
    "status": "FAILED",
    "errorCode": "1501",
    "errorMessage": "Content verification failed, 改提示词或图片",
    "failedReason": {},
    "usage": {
      "consumeMoney": null,
      "consumeCoins": null,
      "taskCostTime": "0",
      "thirdPartyConsumeMoney": null
    },
    "promptTips": "",
    "results": null,
    "taskId": "2015810049043947521"
  },
  "taskId": "2015810049043947521"
}
```

## Enterprise Notes

- API concurrency is 100.
- Enterprise shared API keys require `instanceType`: Standard uses `default`; Plus uses `plus`.
- Recommended local submit concurrency: 80 to 90, leaving room for retries and network jitter.
- Queue tasks locally rather than submitting without a cap.

## Still Worth Confirming

- Full error code list.
- Exact response when concurrency exceeds 100.
- Webhook retry count and interval.
- Webhook signing or source verification.
- Whether Base64 Data URI should be passed in `imageUrls` or `images`; docs mention both patterns.
- Supported image formats for upload.
- Whether upload endpoint has independent size, concurrency, or rate limits.
