---
skill: dev-test
trigger: PM 发起开发任务（/ppt-apply 流程中）
executor: DE
---

## 上下文围栏（Context Fence）

执行本 Skill 前，MUST 严格遵守以下约束：

1. **读取角色定义**: 读取 `agents/de.md`，确认身份和禁止事项
2. **读取 Handoff**: 读取 PM 指定的 `deliverables/{REQ-ID}/.handoff/to-de-{task}.md` 文件
3. **白名单约束**: 仅允许读取 Handoff「允许读取的文件」中列出的路径，读取白名单外文件视为违规
4. **忽略对话历史**: 不得引用对话中其他角色产生的推理、代码或结论，所有输入必须来自文件
5. **输出隔离**: 仅向 Handoff「期望输出」指定路径写入，完成后仅报告文件路径，不在对话中展开产物内容
6. **状态更新**: 完成后在 `deliverables/{REQ-ID}/.state.md`「已完成步骤」追加一行记录

违反以上任何一条，当前产出无效，必须重新执行。

## 视觉设计规范（DE 必读）

开发前必须加载 `skills/design-visual.md`，严格遵守其中所有规则（色彩/字体/布局/内容逻辑/图形元素/分步展示）。

违反任何一条视为自检失败。

---

## 前置条件
- deliverables/{REQ-ID}/sa/design.md 存在且已通过 PM 检查
- SR1-record.md 标记为 PASS
- PM 指定了当前要开发的页面编号

## 断点续作
- 开发前 PM 已执行 `bash src/scripts/resume-check.sh`
- 如果当前页面已存在于 temp_output/ 或 final_output/，跳过该页面
- 只开发 resume-check.sh 输出的待开发页面
- 每完成一个页面后，不在上下文中保留该页面的 HTML 代码，只保留文件路径

## 执行步骤

### Step 1: 读取设计规格
1. 读取 deliverables/{REQ-ID}/sa/design.md
2. 定位 PM 指定的页面设计段落
3. 提取：布局类型、主标题、重点行、卡片内容、图表需求
4. 读取 templates/page-skeleton.html 作为基础结构

### Step 2: 编写验证测试（TDD 红灯）
编写页面验证脚本，测试项包括：
```
- .slide 容器存在，宽度 1280px，高度 720px
- 页面有明确的标题（h1 或等效标题元素）
- 页面内容非空，与 design.md 语义一致
- 无水平溢出（scrollWidth <= clientWidth）
- 无垂直溢出（内容未超出 .slide 容器）
```

将测试写入 deliverables/{REQ-ID}/de/test-{page}.md（文本描述格式，供 TE 执行）

运行测试 → 确认 FAIL（页面尚未实现）

### Step 3: 实现代码（TDD 绿灯）
1. 基于 templates/page-skeleton.html 创建页面文件（仅保留 .slide 容器和脚本引用，页面内部结构完全自由）
2. 填入设计规格中的所有内容：
   - 页面结构由 DE 自主设计，鼓励多样化布局（不要求每页都是三段式）
   - 可选布局风格举例：英雄大图+标题、左右分栏、时间线、数据仪表盘、对比表格、引用金句页、流程图解、卡片网格等
   - 同一份 PPT 中相邻页面应避免使用相同布局，追求视觉节奏感
   - 如有 Mermaid 图表，嵌入 `<div class="mermaid">` 块
3. 视觉增强（必须）：
   - 为关键信息块配置语义图标（从 Lucide Icons 按需下载 SVG 到 `templates/shared/icons/`）
   - 可生成内联 SVG 插图（示意图、流程图解、装饰图形等）增强视觉表达
   - 图标/插图应服务于内容理解，不做纯装饰堆砌
4. 注重视觉效果：间距舒适、层次分明、信息密度适中（避免过于拥挤）
5. 确保 CSS 变量继承自 page-skeleton.html
6. 更新页码

**图标按需下载规则：**
- 图标来源: Lucide Icons（MIT 协议），CDN 地址: `https://unpkg.com/lucide-static/icons/{name}.svg`
- 下载到: `templates/shared/icons/{name}.svg`
- 页面中引用: `<img src="shared/icons/{name}.svg" alt="{描述}" class="icon">`
- 已存在的图标直接复用，不重复下载
- 选择图标时优先语义匹配（如"趋势"用 trending-up，"安全"用 shield 等）

**分步显示规则（强制）：**
- 如果页面内容适合分步展示（如多个卡片、多个要点、流程步骤等），必须为内容块添加 `class="step"`
- 第一个 `.step` 默认可见，后续 `.step` 通过方向键逐步揭示
- 导航逻辑（由 nav.js 自动处理）：
  - →/↓：如果有未揭示的 step，显示下一个 step；全部揭示后跳转下一页
  - ←/↑：如果有已揭示的 step（非第一个），隐藏最后一个；回到第一个时跳转上一页
  - Esc：返回 index.html
- 不适合分步的页面（如单一大图、全幅内容）可不加 `.step`，此时方向键直接翻页

### Step 4: 重构
1. 检查 HTML 结构是否简洁（无冗余嵌套）
2. 检查 CSS 是否有重复声明
3. 确保所有文本内容与 design.md 语义一致
4. 审视视觉效果：布局是否有创意、与相邻页面是否有差异化、信息层次是否清晰

### Step 5: 自检
执行以下检查，全部通过才可提交：

```
[DE 自检清单]
- [ ] 文件存在: deliverables/{REQ-ID}/temp_output/{page}.html
- [ ] 文件非空（> 500 字符）
- [ ] HTML 无未闭合标签
- [ ] .slide 容器: width 1280px, height 720px
- [ ] 页面有标题（h1 或等效）
- [ ] 页面内容非空且与 design.md 语义一致
- [ ] 无溢出（内容未超出 .slide 容器，水平和垂直均不溢出）
- [ ] 视觉效果：布局有创意、层次分明、不千篇一律
- [ ] 页码正确
- [ ] CSS 变量与 page-skeleton.html 一致
- [ ] window.__pptPages 数组已填入所有页面文件名且顺序正确
- [ ] nav.js 和 mermaid-init.js 正确引入
- [ ] 如 design.md 标注有 Mermaid 图表，确认 .mermaid 块存在且语法正确
- [ ] 适合分步展示的内容已添加 .step 类
```

### Step 6: 产出报告
填写 deliverables/{REQ-ID}/de/code-report.md：

```markdown
# 开发报告

## 页面: {page}
- 文件: deliverables/{REQ-ID}/temp_output/{page}.html
- 布局: {布局类型}
- 卡片数: {N}
- 图表: {有/无}
- 自检结果: 全部通过

## 变更说明
{简要描述实现内容}
```

## 输出物
- deliverables/{REQ-ID}/temp_output/{page}.html
- deliverables/{REQ-ID}/de/code-report.md
- deliverables/{REQ-ID}/de/test-{page}.md

## 完成标志
- temp_output/ 下页面文件存在且非空
- 自检清单全部通过
- code-report.md 存在

向 PM 报告：
```
[DE 开发完成]
页面: {page}
文件: deliverables/{REQ-ID}/temp_output/{page}.html
自检: 全部通过
请调度 TE 审计验证
```
