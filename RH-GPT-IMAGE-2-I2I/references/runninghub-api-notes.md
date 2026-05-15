# RunningHub API Notes

Source: https://www.runninghub.cn/runninghub-api-doc-cn/

Key endpoints used by this skill:

- Upload local media: `POST /openapi/v2/media/upload/binary`
  - Auth: `Authorization: Bearer <apiKey>`
  - Body: `multipart/form-data`, field name `file`
  - Important response fields: `data.fileName`, `data.download_url`
  - For ComfyUI `LoadImage.image`, use `fileName` when available.

- Get workflow JSON: `POST /api/openapi/getJsonApiFormat`
  - Body includes `apiKey` and `workflowId`.
  - The response `data.prompt` is JSON text for the workflow graph.
  - Node IDs and field names must match this JSON. A stale node ID causes `NODE_INFO_MISMATCH`.

- Create task: `POST /task/openapi/create`
  - Body includes `apiKey`, `workflowId`, and `nodeInfoList`.
  - `nodeInfoList` items use `nodeId`, `fieldName`, `fieldValue`.
  - Queue/concurrency errors commonly include `TASK_QUEUE_MAXED`.

- Query task: `POST /openapi/v2/query`
  - Auth: `Authorization: Bearer <apiKey>`
  - Body includes `taskId`.
  - Success image URL is usually `results[0].url`.

- Fallback output query: `POST /task/openapi/outputs`
  - Some workflows expose result URLs here instead of `query.results`.
  - Some workflows return success with no output URL; this usually means the workflow output is not API-visible.

Concurrency notes:

- Account/API key concurrency may be lower than enterprise quota pages imply.
- Treat concurrency as "running/queued task slots", not "safe simultaneous HTTP requests".
- For stability, stagger creates and avoid multiple upload processes reading the same source file.
- Multi-reference I2I tasks may run longer than the local 300-second polling window. A local timeout does not mean platform failure; query the saved task ID later and download when `SUCCESS`.
- Do not launch the next batch while prior timed-out tasks are still `RUNNING`, or subsequent creates may return `TASK_QUEUE_MAXED`.
- Batch jobs can use 3 parallel tasks, but only start the next group after the current group has returned success/downloaded or otherwise freed the queue.

Local verified workflow notes:

- Workflow `2047956784060567554` accepts `resolution=1k`, `resolution=2k`, and `resolution=4k` through generation node `15`.
- Default day-to-day resolution for this workflow should be `2k`.
- `4k` can succeed but may take several minutes and may have transient query `504 Gateway Time-out`; keep polling instead of immediately resubmitting.
