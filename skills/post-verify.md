---
skill: post-verify
trigger: PM 发起审计验证任务（/ppt-apply 流程中）
executor: TE
---

## 上下文围栏（Context Fence）

执行本 Skill 前，MUST 严格遵守以下约束：

1. **读取角色定义**: 读取 `agents/te.md`，确认身份和禁止事项
2. **读取 Handoff**: 读取 PM 指定的 `deliverables/{REQ-ID}/.handoff/to-te-{task}.md` 文件
3. **白名单约束**: 仅允许读取 Handoff「允许读取的文件」中列出的路径，读取白名单外文件视为违规
4. **忽略对话历史**: 不得引用对话中其他角色产生的推理、代码或结论，所有输入必须来自文件
5. **输出隔离**: 仅向 Handoff「期望输出」指定路径写入，完成后仅报告文件路径，不在对话中展开产物内容
6. **状态更新**: 完成后在 `deliverables/{REQ-ID}/.state.md`「已完成步骤」追加一行记录

违反以上任何一条，当前产出无效，必须重新执行。

## 前置条件
- 待验证产物存在于 deliverables/{REQ-ID}/temp_output/ 或 final_output/
- DE 的 code-report.md 已提交
- deliverables/{REQ-ID}/te/testcases.md 存在（测试用例已设计）

## 执行步骤

### Step 1: 浏览器 E2E 测试
1. 读取 deliverables/{REQ-ID}/te/testcases.md 中对应页面的 E2E 用例
2. 使用 Playwright 打开待验证页面（禁止使用纯文本/DOM解析替代，必须启动真实浏览器）：
   ```
   操作序列：
   a. 启动浏览器（Chromium）
   b. 设置视口: 1280x720
   c. 打开页面文件（file:// 协议）
   d. 等待页面加载完成
   e. 确认浏览器实例已启动（截图为证）
   ```
3. 逐条执行 E2E 用例中的验证步骤：
   - 检查三段结构存在（header、keypoint、body）
   - 检查文本内容非空
   - 检查容器尺寸（1280x720）
   - 检查无溢出（scrollWidth <= clientWidth）
   - 检查视觉呈现：内容是否可读、层次是否清晰（截图人工判断）
4. 每个用例截图留证：
   - 截图保存到 deliverables/{REQ-ID}/te/screenshots/{page}-{用例ID}.png
5. 记录每条用例结果：PASS / FAIL + 失败原因

### Step 2: 回归测试
1. 检查 output/final/ 中已归档页面是否受影响：
   - 如果 output/final/ 为空（首次开发），跳过此步
   - 如果有已归档页面，计算 hash 对比
2. 检查 index.html 链接有效性（如存在）：
   - 提取所有 href
   - 验证每个链接指向的文件存在

### Step 3: 工程验证
1. **HTML 语法校验**：
   - 检查所有标签正确闭合
   - 检查无重复 id
   - 检查 DOCTYPE 声明存在
   - 检查 charset 声明存在

2. **16:9 容器结构**：
   - .slide 元素存在
   - 样式中 width: 1280px 或 var(--slide-width): 1280px
   - 样式中 height: 720px 或 var(--slide-height): 720px
   - 内容无水平溢出
   - 内容无垂直溢出

3. **页面内容完整性**：
   - 页面有标题（h1 或等效标题元素）
   - 页面内容非空
   - 内容与 design.md 语义一致（关键信息无遗漏）

4. **可访问性基础检查**：
   - html lang 属性存在
   - 图片有 alt 属性（如有图片）
   - 颜色对比度满足基础要求（文字与背景）

5. **键盘导航验证**：
   - window.__pptPages 数组存在且非空
   - 数组中所有文件名对应的文件存在
   - nav.js 正确引入
   - 按 → 键可跳转到下一页（非末页时）
   - 按 ← 键可跳转到上一页（非首页时）
   - 按 Esc 键可返回 index.html
   - 如页面含 `.step` 元素：验证首个 step 默认可见，其余隐藏
   - 按 → 键逐步揭示 step，全部揭示后再按跳转下一页
   - 按 ← 键逐步隐藏 step，回到第一个后再按跳转上一页

6. **Mermaid 图表验证**（如 design.md 标注该页有图表）：
   - mermaid-init.js 正确引入
   - `.mermaid` 元素存在
   - Mermaid 渲染完成后 `.mermaid` 内含 SVG 元素（非原始文本）

### Step 4: 产出报告
1. 使用 templates/test-report-template.md 格式
2. 填写所有测试结果
3. 计算通过率
4. 标记最终结论：
   - 全部通过 → **PASS**
   - 任何 E2E 或工程验证失败 → **FAIL**
   - 仅回归测试有警告 → **PASS（附警告）**

报告写入路径：
- 临时审计：deliverables/{REQ-ID}/te/temp-test-report.md
- 最终审计：deliverables/{REQ-ID}/te/final-test-report.md

## 自检清单
- [ ] 报告文件存在且非空
- [ ] 包含明确的 PASS/FAIL 结论
- [ ] E2E 用例全部有结果记录
- [ ] 工程验证全部有结果记录
- [ ] FAIL 时包含失败项详情和截图路径

## 输出物
- deliverables/{REQ-ID}/te/temp-test-report.md 或 final-test-report.md
- deliverables/{REQ-ID}/te/screenshots/（截图目录）

## 完成标志
报告已写入，向 PM 报告：

审计通过时：
```
[TE 审计完成]
结果: PASS
通过率: {N}%
报告: deliverables/{REQ-ID}/te/{type}-test-report.md
```

审计失败时：
```
[TE 审计完成]
结果: FAIL
通过率: {N}%
失败项: {失败用例ID列表}
报告: deliverables/{REQ-ID}/te/{type}-test-report.md
请 PM 转发 DE 修复
```

## 失败处理
- 审计失败时，报告返回 PM
- PM 将失败详情（失败项 + 截图）转发给 DE
- DE 修复后重新提交，TE 重新审计
- 最多 5 轮，超过则上升到人工审核
- 每轮审计报告追加轮次编号（审计轮次: {N}）
