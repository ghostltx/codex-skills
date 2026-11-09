---
name: sightengine-ai-check
description: 用 Sightengine API 检测图片是否为 AI 生成 (models=genai)。当用户提到 Sightengine、AI图片检测、检测图片是否AI生成、图片AI概率、图片真实性鉴定时使用。
---

# Sightengine AI Check

使用 Sightengine API (`models=genai`) 检测图片是否为 AI 生成。

## 凭据与安全规范

- **API user**: `1625826518`
- **API secret**: 绝不能写死在代码或脚本中，也不能在控制台输出、日志或回复中打印 secret。
- **读取方式**:
  1. 优先读取环境变量 `SIGHTENGINE_API_SECRET`
  2. 未设置时，从长期记忆文件 `%OneDrive%\Codex
otepad.md` 中读取包含 `Sightengine API` 行的 `API secret = ` 后的值。

## 额度与限制 (免费版)

- **总额度**: 2,000 operations/月，最多 500 operations/天（每张图消耗 5 operations，相当于每天约 100 张、每月约 400 张）。
- **频率限制**: 最多 1 次请求/秒。
- **文件限制**: 单张图片大小最大 12 MB。
- **重试策略**: 失败的请求不计费；不要自动重试，避免浪费额度。

## 判断标准

- 返回结果字段: `type.ai_generated`（0 到 1，越接近 1 越可能是 AI 生成）。
- **>= 0.9**：🤖 **AI 生成**（高概率，推荐红色高亮）
- **<= 0.1**：📷 **非 AI / 真实拍摄**（低概率，推荐绿色高亮）
- **0.1 ~ 0.9**：🟡 **不确定 / 混合合成**（中间值，推荐黄色高亮）

## 回复风格规范（强制执行）

当使用此 Skill 检测图片时，**必须遵守以下回复规则**：
1. **简短直接**：只用一两句核心结论说明结果，不要长篇大论。
2. **可视化进度条**：使用类似 `███████████████░░░░░` 的文本进度条直观呈现概率。
3. **生动符号与高亮**：善用 emoji（如 🤖 📷 🟡 ⚡ 📊），对于关键数值（如概率、结论、消耗额度）使用彩色标签或代码块高亮突出，避免全是普通文字。
4. **输出模版参考**：
   > 🎯 **检测完成**：`文件名`
   > 
   > 📊 **AI 概率**：`75.0%` [███████████████░░░░░]
   > 🟡 **综合判定**：<span style="color:#e3b341;font-weight:bold;">不确定 (0.1 ~ 0.9)</span>
   > ⚡ **额度消耗**：5 operations

## 执行方式

运行内置脚本获取结构化结果：

```powershell
# 检测本地图片
& "C:\Users\ghost\.codex\skills\sightengine-ai-check\scripts\check_image.ps1" -ImagePath "C:\path	o\image.png"

# 检测图片网络链接
& "C:\Users\ghost\.codex\skills\sightengine-ai-check\scripts\check_image.ps1" -ImageUrl "https://example.com/image.jpg"
```
