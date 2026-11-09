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
- **>= 0.9**：🔴 🤖 **AI 生成**
- **<= 0.1**：🟢 📷 **非 AI (真实拍摄)**
- **0.1 ~ 0.9**：🟡 🧩 **不确定 (混合/渲染/设计图)**

## 回复风格规范（强制执行）

当使用此 Skill 检测图片时，**严禁输出任何 HTML 标签**（如 `<span>` 等，避免客户端转义裸露），完全使用纯 Markdown 与 Emoji 进行高亮排版：
1. **极简直接**：一两行说明核心结果，不输出多余废话。
2. **可视化进度条**：使用 `███████████████░░░░░` 字符进度条。
3. **色彩与高亮**：用红/黄/绿圆点 Emoji（🔴/🟡/🟢）表达状态色彩，数据与关键结论用加粗行内代码（如 `**75.0%**`）凸显。
4. **输出模版**：
   > 🎯 **检测完成**：`文件名`
   > 
   > 📊 **AI 概率**：`75.0%` [███████████████░░░░░]
   > 🟡 **判定结论**：**不确定 (0.1 ~ 0.9)**
   > ⚡ **额度消耗**：`5 operations`

## 执行方式

运行内置脚本获取结构化结果：

```powershell
# 检测本地图片
& "C:\Users\ghost\.codex\skills\sightengine-ai-check\scripts\check_image.ps1" -ImagePath "C:\path	o\image.png"

# 检测图片网络链接
& "C:\Users\ghost\.codex\skills\sightengine-ai-check\scripts\check_image.ps1" -ImageUrl "https://example.com/image.jpg"
```
