---
name: 故事板
description: Use when the user asks to create, arrange, rewrite, or generate prompts for a commercial storyboard, 6宫格故事版, 视频分镜, 6-panel storyboard, ad storyboard, short-form product video storyboard, or image-generation prompt for a storyboard sheet. Default to a 15-second, 6-panel premium advertising storyboard and output both a Chinese version and an English version unless the user specifies a single language, another duration, panel count, or style.
---

# 故事板

Use this skill to turn a product or campaign idea into a complete image-generation prompt for a polished commercial storyboard sheet.

## Default Output

Respond in Chinese. By default, provide two complete storyboard prompts:
1. `中文版故事板提示词`
2. `English Storyboard Prompt`

Only output one language when the user explicitly asks for Chinese only, English only, or another single-language variant.

Default format:
- Total video length: 15 seconds.
- Storyboard: 6 panels in a clean 3x2 grid.
- Use real storyboard structure, not only a timeline.
- Include title area, product concept, visual direction, 6 panel descriptions, camera movement, transition notes, and bottom timeline table.
- Make the result directly usable as an AI image-generation prompt for one complete storyboard sheet.

Default timing:
- Panel 1: `00:00-00:02`
- Panel 2: `00:02-00:05`
- Panel 3: `00:05-00:07`
- Panel 4: `00:07-00:10`
- Panel 5: `00:10-00:13`
- Panel 6: `00:13-00:15`

## Required Storyboard Prompt Structure

Produce two complete prompts using the same structure: first a Chinese version, then an English version.

Chinese version labels should use Chinese terms such as `产品`, `故事板概念`, `整体情绪`, `目标人群`, `色彩`, `灯光`, `材质重点`, `画面`, `镜头`, `画面文字`, `转场`, and `底部时间轴`.

English version should use this structure:

```text
Create an original high-end English-language 6-panel commercial storyboard layout for a 15-second short video ad.

Product:
[product name]

Storyboard concept:
[one concise sentence describing the commercial story arc]

Overall mood:
[mood keywords]

Target audience:
[audience]

Color palette:
[palette]

Lighting:
[lighting]

Texture and material focus:
[materials]

Layout:
A professional 3x2 storyboard sheet with 6 cinematic panels. Each panel includes image area, shot number, timecode, short English shot copy, camera movement, and transition note. Add a title area at the top and a timeline overview table at the bottom.

Panel 1 | 00:00-00:02 | [shot title]
Visual:
[specific image content]
Camera:
[camera direction]
Text on panel:
SHOT 1 / 00:00-00:02
[short English ad line]
Transition:
[transition]

Panel 2 | 00:02-00:05 | [shot title]
Visual:
[specific image content]
Camera:
[camera direction]
Text on panel:
SHOT 2 / 00:02-00:05
[short English ad line]
Transition:
[transition]

Panel 3 | 00:05-00:07 | [shot title]
Visual:
[specific image content]
Camera:
[camera direction]
Text on panel:
SHOT 3 / 00:05-00:07
[short English ad line]
Transition:
[transition]

Panel 4 | 00:07-00:10 | [shot title]
Visual:
[specific image content]
Camera:
[camera direction]
Text on panel:
SHOT 4 / 00:07-00:10
[short English ad line]
Transition:
[transition]

Panel 5 | 00:10-00:13 | [shot title]
Visual:
[specific image content]
Camera:
[camera direction]
Text on panel:
SHOT 5 / 00:10-00:13
[short English ad line]
Transition:
[transition]

Panel 6 | 00:13-00:15 | [shot title]
Visual:
[specific image content]
Camera:
[camera direction]
Text on panel:
[product headline]
[tagline]
Transition:
Fade out.

Bottom timeline:
00:00-00:02 | Shot 1 | [focus] | [mood] | [transition]
00:02-00:05 | Shot 2 | [focus] | [mood] | [transition]
00:05-00:07 | Shot 3 | [focus] | [mood] | [transition]
00:07-00:10 | Shot 4 | [focus] | [mood] | [transition]
00:10-00:13 | Shot 5 | [focus] | [mood] | [transition]
00:13-00:15 | Shot 6 | [focus] | [mood] | Fade Out

Design style:
The final image should look like a real commercial storyboard presentation created by a premium brand team. Clear 6-panel grid, refined spacing, elegant typography, small uppercase production notes, soft shot labels, polished visual hierarchy, and high-end advertising aesthetics.
```

## Shot Arc Rules

For most product ads, use this arc:
1. Product or packaging reveal.
2. Macro detail / material beauty.
3. Human touch / pickup / interaction.
4. Usage scene / lifestyle moment.
5. Wearing effect / benefit close-up / emotional payoff.
6. Final product lockup with headline and tagline.

Adapt the arc when the product needs a different story, but keep each panel visually distinct.

## Style Rules

- Make each panel a concrete image scene, not an abstract label.
- Include camera language for every panel: slow push-in, macro slider, overhead close-up, over-the-shoulder, beauty push-in, static lockup, etc.
- Include transition notes for every panel.
- Keep visible copy short and premium. Use Chinese copy in the Chinese version and English copy in the English version.
- Avoid stuffing paragraphs into the storyboard image; the prompt can be detailed, but visible text inside the generated storyboard should stay concise.
- For children products, keep the tone cute, safe, sweet, giftable, clean, and parent-friendly. Avoid mature beauty cues.
- For beauty/jewelry products, emphasize soft lighting, skin tones, reflection, macro texture, premium packaging, and elegant typography.
- For ecommerce/Amazon products, include the product's recognizable materials, shape, color, and selling points truthfully from the user's image or description.

## Response Pattern

Start with one short Chinese sentence saying the bilingual storyboard prompts are ready, then provide:

1. A fenced `text` block for `中文版故事板提示词`.
2. A fenced `text` block for `English Storyboard Prompt`.

If the user only says a product name and provides an image, infer:
- product name
- target audience
- palette
- material details
- likely ad story

Ask a question only if the product category or intended style is truly ambiguous.
