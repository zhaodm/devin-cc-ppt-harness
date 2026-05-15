---
skill: design-visual
trigger: SA 架构设计 / DE 编码实现时加载
executor: SA, DE
---

# 视觉设计规范

本文件定义 PPT 页面的视觉设计标准，SA 设计方案时参考，DE 开发时强制遵守。

---

## 色彩

- 仅使用 4 色色板：
  - `#1e2a3a` — 背景（深蓝）
  - `#ffffff` — 主文字（纯白）
  - `#c8d6e5` — 次要文字（浅灰蓝）
  - `#e67e22` — 强调色（橙色）
- 禁止引入红色、绿色或其他额外颜色
- 对比/状态区分用 text-secondary vs accent，不用红绿
- 高对比度：深色背景 + 纯白文字，确保投影清晰

## 字体

| 用途 | 字号 | CSS 变量 |
|------|------|---------|
| h1 标题 | 28-32px | 直接写 |
| 副标题/重点行 | 20px | --font-subtitle |
| 卡片标题 | 22px | --font-card-title |
| 正文/列表/卡片内容 | 18px（最小） | --font-body |
| 标签/辅助文字 | 16px | --font-label |
| 导航/页脚 | 13px | --font-nav |

- 28px 及以上的标题尺寸不调整
- 正文最小 18px，低于此值视为自检失败

## 布局

- 内容在容器内均匀分布：`justify-content: center / space-evenly`，不堆积
- 页面主体在 1280×720 内居中：`align-items: center`
- 禁止连续两页以上使用相同布局结构，相邻页面必须有差异化
- 单行语义的内容不用 `<br>` 强制换行，用缩短措辞或调整字号适配
- 页面内部结构不限于三段式，DE 自主选择最佳呈现方式
- 可选布局风格：英雄大图、左右分栏、时间线、数据仪表盘、对比表格、引用金句页、流程图解、卡片网格等

## 内容逻辑

- 正文内容的组织逻辑必须围绕标题和重点行的核心观点展开
- 左右分栏时按因果/递进关系分组，相关联的概念放同一侧，不按篇幅平均分
- 每个信息块建议包含：结论 + 支撑细节，避免空洞罗列

## 图形元素

- 每页必须包含图形元素，禁止纯文本页面
- 图形元素类型（至少使用一种）：
  - 语义图标（Lucide Icons，按需下载到 `templates/shared/icons/`）
  - 内联 SVG 插图（示意图、流程图解、装饰图形）
  - 真实高清图片（从网上下载到 `templates/shared/images/`）
  - Mermaid 图表
- 图标/图片必须语义匹配页面内容，禁止无关装饰
- 图片优先选择大尺寸、高清晰度的来源

## 分步展示

- 适合分步展示的内容（多卡片、多要点、流程步骤等）必须添加 `class="step"`
- 第一个 `.step` 默认可见，后续通过方向键逐步揭示
- 不适合分步的页面（单一大图、全幅内容）可不加 `.step`

## 资源路径

| 类型 | 存放路径 | 引用方式 |
|------|---------|---------|
| 图标 SVG | `templates/shared/icons/{name}.svg` | `<img src="shared/icons/{name}.svg" class="icon">` |
| 图片 | `templates/shared/images/{name}.{ext}` | `<img src="shared/images/{name}.{ext}">` |
| 样式 | `templates/shared/styles.css` | `<link rel="stylesheet" href="shared/styles.css">` |

## 图标按需下载

- 来源：Lucide Icons（MIT 协议）
- CDN：`https://unpkg.com/lucide-static/icons/{name}.svg`
- 已存在的图标直接复用，不重复下载
- 选择时优先语义匹配（如"趋势"用 trending-up，"安全"用 shield）

## 图片下载

- 需要配图时从网上搜索高质量图片
- 下载到 `templates/shared/images/` 目录
- 文件名语义化（如 `ai-robot.jpg`，不用 `img1.jpg`）
