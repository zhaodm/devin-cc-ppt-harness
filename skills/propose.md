---
skill: propose
trigger: /ppt-propose 命令
executor: SA（PM 调度）、TE（测试用例）
---

## 上下文围栏（Context Fence）

SA/TE 执行本 Skill 中的步骤前，MUST 严格遵守以下约束：

1. **读取角色定义**: 读取 `agents/{当前角色}.md`，确认身份和禁止事项
2. **读取 Handoff**: 读取 PM 指定的 `deliverables/{REQ-ID}/.handoff/to-{role}-{task}.md` 文件
3. **白名单约束**: 仅允许读取 Handoff「允许读取的文件」中列出的路径，读取白名单外文件视为违规
4. **忽略对话历史**: 不得引用对话中其他角色产生的推理、代码或结论，所有输入必须来自文件
5. **输出隔离**: 仅向 Handoff「期望输出」指定路径写入，完成后仅报告文件路径，不在对话中展开产物内容
6. **状态更新**: 完成后在 `deliverables/{REQ-ID}/.state.md`「已完成步骤」追加一行记录

PM 执行 Step 4 时，遵守 PM 围栏：仅依据产出文件内容做判断，不依赖 SA/TE 的对话推理。

违反以上任何一条，当前产出无效，必须重新执行。

## 前置条件
- src/scripts/propose.sh 执行 PASS
- deliverables/{REQ-ID}/proposal.md 存在且状态为 READY

## 执行步骤

### Step 1: 需求分析（REQ-1）— SA 执行

**输入**: deliverables/{REQ-ID}/proposal.md
**输出**: deliverables/{REQ-ID}/sa/requirement-spec.md
**模板**: templates/requirement-spec-template.md

执行要求：
1. 读取 proposal.md 全文
2. 将每个章节的核心论点转化为 SHALL 格式的功能需求
3. 为每条需求编写 GWT（Given-When-Then）验收场景
4. 填写页面需求清单表格（每页的布局类型、信息密度）
5. 填写需求追溯矩阵（每条需求对应 proposal 的哪个段落）
6. 非功能需求固定填写：
   - 视觉风格: Claude Design 暖色调 + 咨询级信息密度
   - 分辨率: 16:9（1280x720）
   - 浏览器兼容: Chrome/Edge/Safari 最新版

**自检**：
- [ ] 文件存在且非空
- [ ] 至少包含 2 条 SHALL 格式需求
- [ ] 每条需求有 GWT 验收场景
- [ ] 页面需求清单与 proposal 章节数一致
- [ ] 需求追溯矩阵无空行

### Step 2: 架构设计（REQ-2）— SA 执行

**输入**: deliverables/{REQ-ID}/sa/requirement-spec.md
**输出**: deliverables/{REQ-ID}/sa/design.md
**模板**: templates/design-template.md

执行要求：
1. 读取 requirement-spec.md
2. 设计章节划分和文件命名（chapter-{NN}.html）
3. 为每个页面填写详细设计：
   - 布局选型（3栏/2栏/全幅/左右分栏）
   - 主标题文案
   - 重点行金句
   - 每个卡片/分块的内容（标题/结论/细节/证据）
   - 图表需求（Mermaid 类型或无）
4. 填写需求→技术落实对照表
5. 填写组件清单（标注复用来源）
6. 填写交付顺序（Tasks 清单）
7. 绘制时序图（Mermaid sequenceDiagram）

**自检**：
- [ ] 文件存在且非空
- [ ] 每个页面有明确的布局选型
- [ ] 每个页面的卡片内容遵循 3x3 深度原则（结论+细节+证据）
- [ ] 需求→技术对照表覆盖所有 FR
- [ ] 交付顺序清单存在

### Step 3: 测试用例设计（REQ-3）— TE 执行

**输入**: deliverables/{REQ-ID}/sa/requirement-spec.md
**输出**: deliverables/{REQ-ID}/te/testcases.md
**模板**: templates/testcases-template.md

执行要求：
1. 读取 requirement-spec.md
2. 为每条功能需求编写至少 1 个 E2E 测试用例：
   - 明确 Playwright 操作步骤
   - 明确期望结果（可截图验证的）
3. 编写回归测试用例：
   - 已归档页面 hash 对比
   - 索引页链接有效性
4. 编写工程验证用例：
   - HTML 语法校验
   - 16:9 容器结构检查
   - 排版规范三段结构检查

**自检**：
- [ ] 文件存在且非空
- [ ] E2E 用例数 >= 功能需求数
- [ ] 每个 E2E 用例有明确的 Playwright 步骤
- [ ] 包含回归测试用例
- [ ] 包含工程验证用例

### Step 4: 需求评审（SR1）— PM 执行

1. 执行 `bash src/scripts/verify.sh {REQ-ID} B`
2. 检查三个产物的自检项是否全部通过
3. 创建基线快照：
   ```bash
   cp deliverables/{REQ-ID}/sa/requirement-spec.md deliverables/{REQ-ID}/baselines/requirement-spec.v1.md
   cp deliverables/{REQ-ID}/sa/design.md deliverables/{REQ-ID}/baselines/design.v1.md
   cp deliverables/{REQ-ID}/te/testcases.md deliverables/{REQ-ID}/baselines/testcases.v1.md
   ```
4. 填写 deliverables/{REQ-ID}/SR1-record.md（使用 templates/sr-record-template.md）
5. 向用户呈现人工审批：
   ```
   [人工审批节点]
   评审节点: SR1 需求评审
   审批内容摘要:
     - 结构化需求: {N} 条功能需求
     - 页面设计: {N} 个页面
     - 测试用例: {N} 条
   相关产物:
     - deliverables/{REQ-ID}/sa/requirement-spec.md
     - deliverables/{REQ-ID}/sa/design.md
     - deliverables/{REQ-ID}/te/testcases.md
   请确认: 通过 / 驳回（请说明原因）
   ```
6. 用户通过：SR1-record.md 标记 PASS
7. 用户驳回：记录原因，回退到对应步骤

## 输出物
- deliverables/{REQ-ID}/sa/requirement-spec.md
- deliverables/{REQ-ID}/sa/design.md
- deliverables/{REQ-ID}/te/testcases.md
- deliverables/{REQ-ID}/SR1-record.md（PASS）
- deliverables/{REQ-ID}/baselines/*.v1.md

## 完成标志
SR1-record.md 标记为 PASS，向用户报告：
```
[/ppt-propose 完成]
需求编号: {REQ-ID}
评审结果: PASS
下一步: 输入 /ppt-apply 启动开发与审计
```
