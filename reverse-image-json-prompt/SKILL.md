---
name: reverse-image-json-prompt
description: Turn one or more product, character, scene, poster, ecommerce, or reference images into concise Chinese JSON image-generation prompts, and rewrite existing JSON prompts according to user change requests. Use when the user asks to reverse-engineer an image prompt, summarize an image as JSON, create a stable prompt structure from an image, or adjust/rewrite a generated JSON prompt.
---

# Reverse Image JSON Prompt

## Goal

Use this skill to convert visual content into a reusable Chinese JSON prompt for image generation. Keep output practical: no Markdown wrappers, no explanation unless the user asks, and no invented certainty about unreadable details.

## Image To JSON

When the user provides an image and asks to reverse, analyze, or create a prompt, use this core instruction:

```text
观察图片并输出一个用于复现画面的 JSON 对象。
不要标题，不要解释，不要 Markdown。

输出一个合法 JSON 对象，所有字段值使用中文。
字段使用稳定结构：
subject, scene, action, composition, lighting, style, colors, camera, clothing, hair, accessories, environment, props, materials, mood, key_details。

信息尽量完整，但避免重复。
```

Return a JSON object with these fields when applicable:

```json
{
  "subject": "",
  "scene": "",
  "action": "",
  "composition": "",
  "lighting": "",
  "style": "",
  "colors": "",
  "camera": "",
  "clothing": "",
  "hair": "",
  "accessories": "",
  "environment": "",
  "props": "",
  "materials": "",
  "mood": "",
  "key_details": ""
}
```

Rules:

- Use Chinese for all values unless the user requests another language.
- Preserve useful visible details: subject identity/category, pose, perspective, camera angle, material, surface texture, lighting direction, color palette, layout, background, text placement, and product features.
- For ecommerce/product images, emphasize product shape, material, color, angle, scene, props, labels/text areas, size cues, and selling-point visual logic.
- For posters or UI-like images, include typography, hierarchy, graphic style, layout zones, background treatment, and visible text only when legible.
- If a field is not relevant, use an empty string or a short "无明显..." value. Do not hallucinate specifics such as brand, exact material, or exact camera lens unless visible.
- Keep the JSON valid: double quotes, no trailing comma, no comments.

## Rewrite Existing JSON

When the user gives an existing JSON prompt and an adjustment target, rewrite the full JSON coherently instead of doing narrow find-and-replace. Use this instruction:

```text
你是专业的 AI 绘画 JSON 提示词重写助手。
任务：根据用户的调整目标，重写下面的 JSON 图像描述。
要求：
1. 只输出合法 JSON，不要解释，不要 Markdown。
2. 尽量保持原 JSON 的字段结构、层级和详细程度。
3. 不要做简单替换，要让主体、动作、服装、姿势、道具、场景、光线、氛围、摄影细节和所有相关描述通篇合理同步。
4. 如果用户把男人改成女人，所有人物外观、身体姿势、服装、发型、气质和相关细节都要自然适配女人。
5. 如果用户把篮球改成足球，场景、动作、球场、装备、姿势和运动语境都要自然改成足球。
用户调整目标：{rewriteTarget}
当前 JSON：
{currentJson}
```

Rewrite rules:

- Preserve the user's existing field names and nesting unless they ask to change structure.
- Update every related field consistently.
- Keep stable visual intent from the original unless the change target conflicts with it.
- Return only the rewritten JSON.

## Response Shape

Default response for image-to-prompt tasks:

```json
{
  "subject": "...",
  "scene": "...",
  "action": "...",
  "composition": "...",
  "lighting": "...",
  "style": "...",
  "colors": "...",
  "camera": "...",
  "clothing": "...",
  "hair": "...",
  "accessories": "...",
  "environment": "...",
  "props": "...",
  "materials": "...",
  "mood": "...",
  "key_details": "..."
}
```

If the user asks for both Chinese and English, return:

```json
{
  "zh": { },
  "en": { }
}
```

If the user asks for a generation-ready plain prompt instead of JSON, produce a concise Chinese paragraph after the JSON or instead of it, matching the user's requested format.
