# RH100-T2I RunningHub API Reference

## Endpoint

Submit:

```http
POST https://www.runninghub.cn/openapi/v2/rhart-image-n-g31-flash/text-to-image
```

Query:

```http
POST https://www.runninghub.cn/openapi/v2/query
```

## Auth

```http
Authorization: Bearer ${RUNNINGHUB_API_KEY}
Content-Type: application/json
```

The bundled script reads `RH100_T2I_API_KEY` first, then `RUNNINGHUB_API_KEY`.

## Submit Body

```json
{
  "prompt": "一幅精美的明代国漫风格插画。一位穿着飞鱼服的锦衣卫站在古老的城墙上，俯瞰着繁华的京城夜景。",
  "aspectRatio": "1:1",
  "resolution": "2k",
  "instanceType": "default",
  "webhookUrl": "https://example.com/webhook"
}
```

Fields:

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `prompt` | `String` | yes | Text prompt. Local capability data shows this endpoint prompt as required. Related endpoints document max 20000 characters. |
| `aspectRatio` | `String` | no | Script default `1:1`; enum below. |
| `resolution` | `String` | yes | `1k`, `2k`, `4k`; script default `2k`. |
| `instanceType` | `String` | enterprise shared | `default` for Standard, `plus` for Plus. Omit for Lite auto-scheduling. |
| `webhookUrl` | `String` | no | Receives task end POST callback when supported. |

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

`results[].url` expires after 24 hours. Download immediately.

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

- API concurrency is 100 for the RH100 enterprise lane.
- Enterprise shared API keys require `instanceType`: Standard uses `default`; Plus uses `plus`.
- Recommended local submit concurrency: 80 to 90, leaving room for retries and network jitter.
- Queue tasks locally rather than submitting without a cap.

## Source Notes

The public API detail page is dynamic-rendered, so the static HTML contains only the Nuxt shell. The endpoint and parameter list were cross-checked from local RunningHub capability data and the analogous RH100 image-to-image API contract.
