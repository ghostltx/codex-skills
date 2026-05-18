# RunningHub API Notes

Relevant endpoints for generic workflow submission:

- Base URL: `https://www.runninghub.cn`
- Workflow JSON: `POST /api/openapi/getJsonApiFormat`
- Create workflow task: `POST /task/openapi/create`
- Query task: `POST /openapi/v2/query`
- Fallback outputs query: `POST /task/openapi/outputs`

The generic T2I script edits workflow inputs through `nodeInfoList`:

```json
{
  "apiKey": "...",
  "workflowId": "WORKFLOW_ID",
  "nodeInfoList": [
    { "nodeId": "2", "fieldName": "text", "fieldValue": "prompt" }
  ]
}
```

Use workflow JSON discovery first. Custom workflows vary heavily, so manual node overrides remain necessary when a graph has multiple text nodes or uncommon field names.
