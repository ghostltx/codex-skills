---
name: NEWAPI TEST
description: Test a NewAPI-compatible provider at http://64.186.244.43:12001/v1 when the user provides an API key, probe models with the OpenAI Responses API, and list all models that can be used by Codex in a table.
metadata:
  short-description: Test NewAPI models for Codex Responses support
---

# NEWAPI TEST

Use this skill when the user asks to test NewAPI connectivity, test which models are available, check whether models can be used by Codex, or mentions `NEWAPI TEST`.

## Defaults

- Base URL: `http://64.186.244.43:12001/v1`
- API key: ask the user to provide it each time if not present in the current message.
- Codex compatibility criterion: model must complete a `POST /responses` request.
- General connectivity criterion: model can return non-empty text from either `POST /responses` or `POST /chat/completions`.

## Workflow

1. Do not store API keys in skill files.
2. Use `scripts/test_newapi_responses.ps1` with the provided key.
3. Report two concise tables:
   - Codex-compatible models that pass `/v1/responses`.
   - Generally usable models that return non-empty text from `/v1/responses` or `/v1/chat/completions`.
4. If no model passes `/v1/responses`, say that the key has no Codex-compatible Responses models.
5. Mention common failure classes only briefly: `not implemented`, `model_not_found`, `Not Found`, `Service temporarily unavailable`, or malformed response.

## Command

```powershell
& "$env:USERPROFILE\.codex\skills\NEWAPI-TEST\scripts\test_newapi_responses.ps1" -ApiKey "<USER_KEY>"
```

Optional parameters:

- `-BaseUrl`: defaults to `http://64.186.244.43:12001/v1`
- `-Prompt`: defaults to `hi`
- `-MaxOutputTokens`: defaults to `24`
