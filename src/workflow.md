# PM 调度手册（Workflow）

本文件定义 PM 在每个斜杠命令触发后的完整行为序列。PM 必须严格按此手册执行，不得跳步或自行决策技术问题。

---

## 通用规则

### 角色切换指令格式
PM 向其他角色发送任务时，使用以下标准格式：

```
[调度指令]
目标角色: {SA/DE/TE}
任务类型: {任务名称}
Handoff 文件: deliverables/{REQ-ID}/.handoff/to-{role}-{task-slug}.md
输入物: {文件路径列表}
输出物: {期望产出路径}
参考: {对应 skill 文件路径}
```

### Handoff 协议（角色切换前必须执行）

PM 在每次调度非 PM 角色前，MUST 按以下顺序执行：

0. 打印心跳: `[PM] 调度 {角色} 执行 {任务类型}，页面: {page 或 N/A}`
1. 写入 Handoff 文件 → `deliverables/{REQ-ID}/.handoff/to-{role}-{task-slug}.md`
   - 使用 templates/handoff-template.md 格式
   - 白名单必须精确列出目标角色可读取的每一个文件路径（禁止通配符）
   - task-slug 命名: 小写英文连字符，如 req-analysis, arch-design, dev-p01, audit-p01
2. 更新 `.state.md` → active_role, status, last_updated
3. 发出 [调度指令]（含 Handoff 文件路径字段）
4. 追加日志到 `deliverables/{REQ-ID}/process.log`

目标角色完成后，PM：
5. 验证产出物（文件存在 + 非空 + 格式合规）
6. 更新 `.state.md`（追加已完成步骤、恢复 active_role 为 PM）
7. 追加日志到 `deliverables/{REQ-ID}/process.log`

### 心跳打印规则

PM 在以下时机必须打印心跳信息（格式: `[PM] {描述}`）：

- 调度角色前: `[PM] 调度 SA 执行需求分析`
- 角色完成后: `[PM] SA 需求分析完成，产物已验证`
- 人工审批前: `[PM] 进入 SR1 人工审批`
- 审批结果后: `[PM] SR1 审批通过` 或 `[PM] SR1 审批驳回，回退到 Step X`
- 异常处理时: `[PM] TE 审计失败（轮次 2/5），转发 DE 修复`
- 流程开始时: `[PM] /ppt-propose 流程启动，REQ-ID: REQ001`
- 流程结束时: `[PM] /ppt-propose 流程完成`

### 过程日志规则

所有角色的执行过程必须记录到 `deliverables/{REQ-ID}/process.log`，格式：

```
[{时间}] [{角色}] {事件描述}
```

示例：
```
[2026-05-14T10:00:00Z] [PM] /ppt-propose 流程启动
[2026-05-14T10:00:01Z] [PM] 调度 SA 执行需求分析
[2026-05-14T10:01:30Z] [SA] 需求分析完成，输出: deliverables/REQ001/sa/requirement-spec.md
[2026-05-14T10:01:31Z] [PM] SA 需求分析完成，产物已验证
[2026-05-14T10:01:32Z] [PM] 调度 SA 执行架构设计
```

日志写入规则：
- PM 每次调度前、验证后各追加一条
- SA/DE/TE 完成任务后追加一条（含产物路径）
- 人工审批结果追加一条
- 异常/失败追加一条（含原因摘要）

### 断点恢复协议

PM 恢复执行时（新会话或上下文重置后）：
1. 读取 `deliverables/{REQ-ID}/.state.md`
2. 根据 phase + active_role + status 确定恢复点
3. 如果 status=running：检查期望输出是否已存在
   - 已存在 → 视为完成，更新状态，继续下一步
   - 不存在 → 重新创建 Handoff 发起该步骤
4. 禁止依赖对话历史推断进度

### 异常处理
- 任何步骤产出物自检失败 → 回退到该步骤重新执行
- TE 审计失败 → 将失败报告转发 DE 修复，最多 5 轮
- 超过 5 轮 → 暂停流程，上升到人工审核
- 人工审批驳回 → 记录驳回原因，回退到对应步骤

### 人工审批呈现格式
```
[人工审批节点]
评审节点: {SR1/SR2/SR3/SR4}
审批内容摘要:
  - {要点1}
  - {要点2}
相关产物: {文件路径列表}
请确认: 通过 / 驳回（请说明原因）
```

---

## /ppt-init 流程

### 触发条件
用户输入 `/ppt-init`

### 执行序列

**Step 1: 场景检测**
- 执行 `bash src/scripts/init-task.sh`
- 根据脚本输出的 MODE 字段判断场景：

**MODE = RESUME（断点续作）：**
- 脚本输出未完成的 REQ-ID
- 向用户确认："检测到未完成的 {REQ-ID}，是否继续？"
  - 用户确认继续：读取该 REQ 的 .state.md，根据 phase 提示用户输入对应命令（/ppt-propose 或 /ppt-apply）
  - 用户要求放弃：将该 REQ 的 .state.md phase 改为 done，重新执行 init-task.sh
- 流程结束（不创建新 REQ）

**MODE = NEW（全新项目）：**
- 记录返回的 REQ-ID
- 继续 Step 2（完整需求澄清）

**MODE = CHANGE（变更迭代）：**
- 记录返回的 REQ-ID
- 脚本已自动备份当前 spec/ 到 spec/baselines/
- 继续 Step 2（变更模式需求澄清）

---

**Step 2: 检查 reference/**
- 检查 reference/ 下是否有输入文件
- 如果为空：提示用户放入纲要文件，等待用户操作后继续
- 如果有文件：进入 Step 3

**Step 3: 启动需求澄清**
- 读取 skills/init-clarify.md
- 以 PM 身份执行需求澄清 SOP
- 读取 reference/ 下所有文件
- 如有图片，调用 zai-vision MCP 识别内容
- **变更模式额外操作：**
  - 读取 spec/requirement-spec.md 和 spec/design.md 作为现有基线
  - 澄清聚焦变更点：新增了什么、修改了什么、删除了什么
  - 不重复讨论未变更的内容

**Step 4: 缺失项检测**
- 对照 templates/proposal-template.md 的必填项
- 列出所有缺失信息
- **变更模式：** 仅检测变更相关的必填项，未变更部分标注"沿用基线"

**Step 5: 交互澄清（循环）**
- 每轮向用户提出最多 3 个问题
- 收集回答后更新 proposal 草稿
- 循环直到所有必填项补齐
- **变更模式：** 问题仅围绕变更点，不重复确认已有内容

**Step 6: 定稿确认**
- 向用户展示完整 proposal 草稿
- **变更模式：** 明确标注哪些是变更项、哪些沿用基线
- 用户确认后：
  - 写入 deliverables/{REQ-ID}/proposal.md
  - 将状态字段改为 READY
  - 自检：文件存在 + 非空 + 状态为 READY
- 用户要求修改：回到 Step 5

**完成输出**
```
[/ppt-init 完成]
需求编号: {REQ-ID}
模式: {NEW/CHANGE}
产物: deliverables/{REQ-ID}/proposal.md (READY)
基线备份: {spec/baselines/*.vN.md 或 N/A}
下一步: 用户输入 /ppt-propose
```

---

## /ppt-propose 流程

### 触发条件
用户输入 `/ppt-propose`

### 执行序列

**Step 1: 前置检查**
- 执行 `bash src/scripts/propose.sh`
- 如果 FAIL：向用户报告失败原因，终止
- 如果 PASS：继续

**Step 2: 调度 SA 需求分析（REQ-1）**

2a. 写入 Handoff 文件:
- 路径: deliverables/{REQ-ID}/.handoff/to-sa-req-analysis.md
- 白名单: agents/sa.md, deliverables/{REQ-ID}/proposal.md, templates/requirement-spec-template.md
- 输出: deliverables/{REQ-ID}/sa/requirement-spec.md

2b. 更新 .state.md: active_role=SA, status=running

2c. 发出调度指令:
```
[调度指令]
目标角色: SA
任务类型: 需求分析
Handoff 文件: deliverables/{REQ-ID}/.handoff/to-sa-req-analysis.md
输入物: deliverables/{REQ-ID}/proposal.md
输出物: deliverables/{REQ-ID}/sa/requirement-spec.md
参考: skills/propose.md Step 1, templates/requirement-spec-template.md
```
- SA 完成后，PM 自检产出物：文件存在 + 非空 + 包含 SHALL 格式需求
- 更新 .state.md: 追加已完成步骤，active_role=PM

**Step 3: 调度 SA 架构设计（REQ-2）**

3a. 写入 Handoff 文件:
- 路径: deliverables/{REQ-ID}/.handoff/to-sa-arch-design.md
- 白名单: agents/sa.md, deliverables/{REQ-ID}/sa/requirement-spec.md, templates/design-template.md
- 输出: deliverables/{REQ-ID}/sa/design.md

3b. 更新 .state.md: active_role=SA, status=running

3c. 发出调度指令:
```
[调度指令]
目标角色: SA
任务类型: 架构设计
Handoff 文件: deliverables/{REQ-ID}/.handoff/to-sa-arch-design.md
输入物: deliverables/{REQ-ID}/sa/requirement-spec.md
输出物: deliverables/{REQ-ID}/sa/design.md
参考: skills/propose.md Step 2, templates/design-template.md
```
- SA 完成后，PM 自检产出物：文件存在 + 非空 + 包含页面设计清单
- 更新 .state.md: 追加已完成步骤，active_role=PM

**Step 4: 调度 TE 测试用例设计（REQ-3）**

4a. 写入 Handoff 文件:
- 路径: deliverables/{REQ-ID}/.handoff/to-te-testcase-design.md
- 白名单: agents/te.md, deliverables/{REQ-ID}/sa/requirement-spec.md, templates/testcases-template.md
- 输出: deliverables/{REQ-ID}/te/testcases.md

4b. 更新 .state.md: active_role=TE, status=running

4c. 发出调度指令:
```
[调度指令]
目标角色: TE
任务类型: 测试用例设计
Handoff 文件: deliverables/{REQ-ID}/.handoff/to-te-testcase-design.md
输入物: deliverables/{REQ-ID}/sa/requirement-spec.md
输出物: deliverables/{REQ-ID}/te/testcases.md
参考: skills/propose.md Step 3, templates/testcases-template.md
```
- TE 完成后，PM 自检产出物：文件存在 + 非空 + 包含 E2E/回归/工程三类用例
- 更新 .state.md: 追加已完成步骤，active_role=PM

**Step 5: 需求评审（SR1）**
- 执行 `bash src/scripts/verify.sh {REQ-ID} B`
- 汇总检查结果
- 创建基线快照：
  - cp requirement-spec.md → baselines/requirement-spec.v1.md
  - cp design.md → baselines/design.v1.md
  - cp testcases.md → baselines/testcases.v1.md
- 基于 templates/sr-record-template.md 创建 deliverables/{REQ-ID}/SR1-record.md
- 填写「需求评审检查（SR1 专用）」段落：需求完整性、设计可行性、测试覆盖度

**Step 6: 人工审批 1**
- 向用户呈现（使用人工审批呈现格式）：
  ```
  [人工审批节点]
  评审节点: SR1
  审批内容摘要:
    - 结构化需求文档（SHALL 格式）
    - 页面设计方案（布局 + 内容规划）
    - 测试用例（E2E/回归/工程三类）
    - verify.sh B 级检查结果
  相关产物: deliverables/{REQ-ID}/sa/requirement-spec.md, deliverables/{REQ-ID}/sa/design.md, deliverables/{REQ-ID}/te/testcases.md
  请确认: 通过 / 驳回（请说明原因）
  ```
- 用户通过：SR1-record.md 标记 PASS，流程完成
- 用户驳回：SR1-record.md 标记 FAIL，记录原因，回退到对应步骤重新执行

**完成输出**
```
[/ppt-propose 完成]
需求编号: {REQ-ID}
产物:
  - deliverables/{REQ-ID}/sa/requirement-spec.md
  - deliverables/{REQ-ID}/sa/design.md
  - deliverables/{REQ-ID}/te/testcases.md
  - deliverables/{REQ-ID}/SR1-record.md (PASS)
  - deliverables/{REQ-ID}/baselines/*.v1.md
下一步: 用户输入 /ppt-apply
```

---

## /ppt-apply 流程

### 触发条件
用户输入 `/ppt-apply`

### 执行序列

**Step 1: 前置检查**
- 执行 `bash src/scripts/apply.sh`
- 如果 FAIL：向用户报告失败原因，终止
- 如果 PASS：继续
- 执行 `bash src/scripts/resume-check.sh` 识别已完成页面
- 从 design.md 中读取页面清单，跳过已完成页面，确定待开发顺序

**Token 节流规则（贯穿整个 apply 流程）：**
- 每完成一个页面的开发+审计后，清洗上下文中该页面的 HTML 代码
- 只保留文件路径引用（如"已完成: deliverables/REQ001/temp_output/chapter-01.html"）
- 下一页开发时重新读取 design.md 对应段落，不依赖上下文中的历史代码

**Step 2-3: 逐页开发+审计循环**

⚠️ **关键约束：以下 Step 2、Step 3、Step 3b 是一个循环体，对每个页面都必须完整执行一遍。禁止批量开发多个页面后再统一审计。每个页面必须走完 DE开发→TE审计→人工检查 后，才能开始下一个页面的开发。**

```
FOR 每个待开发页面 IN design.md 页面清单（跳过已完成）:
    Step 2: DE 开发该页面
    Step 3: TE 审计该页面（失败则循环修复，最多5轮，超过上升人工）
    Step 3b: 人工检查该页面（轻量确认，无轮次限制）
    → 清洗上下文中该页面 HTML 代码，只保留文件路径
    → 继续下一个页面
END FOR

所有页面开发+审计+人工检查完成后:
    Step 4: 人工审批 SR2（正式审批，覆盖所有页面）
    Step 5: DE 代码合并（所有页面）
    Step 6: TE 最终审计（所有页面）
    Step 7: 人工审批 SR3（所有页面）
```

---

**Step 2: DE 开发当前页面（DEV-1）**

[PM] 调度 DE 开发 {page}

2a. 写入 Handoff 文件:
- 路径: deliverables/{REQ-ID}/.handoff/to-de-dev-p{NN}.md
- 白名单: agents/de.md, deliverables/{REQ-ID}/sa/design.md (页面 P{NN} 部分), templates/page-skeleton.html, templates/layouts/{布局}.html, templates/shared/styles.css
- 输出: deliverables/{REQ-ID}/temp_output/{page}.html

2b. 更新 .state.md: active_role=DE, current_page={page}, status=running

2c. 发出调度指令:
```
[调度指令]
目标角色: DE
任务类型: 编码实现
Handoff 文件: deliverables/{REQ-ID}/.handoff/to-de-dev-p{NN}.md
输入物: deliverables/{REQ-ID}/sa/design.md (页面 P{NN} 部分)
输出物: deliverables/{REQ-ID}/temp_output/{page}.html
参考: skills/dev-test.md, templates/page-skeleton.html
```
- DE 完成后，PM 自检：文件存在 + 非空 + HTML 结构完整
- 更新 .state.md: 追加已完成步骤，active_role=PM

**Step 3: TE 审计当前页面（TEST-1）**

[PM] 调度 TE 审计 {page}

3a. 写入 Handoff 文件:
- 路径: deliverables/{REQ-ID}/.handoff/to-te-audit-p{NN}.md
- 白名单: agents/te.md, deliverables/{REQ-ID}/temp_output/{page}.html, deliverables/{REQ-ID}/te/testcases.md, deliverables/{REQ-ID}/de/code-report.md, templates/test-report-template.md
- 输出: deliverables/{REQ-ID}/te/temp-test-report.md

3b. 更新 .state.md: active_role=TE, status=running

3c. 发出调度指令:
```
[调度指令]
目标角色: TE
任务类型: 审计验证
Handoff 文件: deliverables/{REQ-ID}/.handoff/to-te-audit-p{NN}.md
输入物: deliverables/{REQ-ID}/temp_output/{page}.html
输出物: deliverables/{REQ-ID}/te/temp-test-report.md
参考: skills/post-verify.md, templates/test-report-template.md
```
- TE 完成后，PM 检查审计结论
- 更新 .state.md: 追加已完成步骤，active_role=PM

**Step 3a: 审计失败处理（最多 5 轮）**
- 如果 FAIL：
  - 轮次 < 5：
    - 写入新 Handoff: deliverables/{REQ-ID}/.handoff/to-de-dev-p{NN}-fix-r{N}.md
    - 白名单增加: deliverables/{REQ-ID}/te/temp-test-report.md（失败详情）
    - 更新 .state.md: round_count+1
    - 回到 Step 2（同一页面）
  - 轮次 >= 5：暂停，上升到人工审核
- 如果 PASS：继续 Step 3b

**Step 3b: 逐页人工检查**

[PM] 进入逐页人工检查 {page}

- 向用户呈现当前页面信息：
  ```
  [逐页人工检查]
  页面: {page}
  文件: deliverables/{REQ-ID}/temp_output/{page}.html
  审计报告: deliverables/{REQ-ID}/te/temp-test-report.md
  请确认: 通过 / 驳回（请说明原因）
  ```
- 用户通过：
  - 清洗上下文中当前页面 HTML 代码，只保留文件路径
  - 更新 .state.md: pages_done+1, round_count=0
  - 追加日志到 process.log
  - 如果还有待开发页面 → 回到 Step 2（下一个页面）
  - 如果所有页面完成 → 继续 Step 4
- 用户驳回：
  - 记录驳回原因
  - 写入新 Handoff: deliverables/{REQ-ID}/.handoff/to-de-dev-p{NN}-fix-r{N}.md
  - 回到 Step 2（同一页面，DE 修复）
  - 注意：人工检查驳回无轮次限制，用户可反复修改直到满意

---

**Step 4: 功能评审（SR2）— 人工审批**

[PM] 进入 SR2 人工审批（所有页面）

- 基于 templates/sr-record-template.md 创建 deliverables/{REQ-ID}/SR2-record.md
- 填写「功能验证检查（SR2/SR3 专用）」段落：逐页记录 TE 审计结果和显示效果
- 向用户呈现（使用人工审批呈现格式）：
  ```
  [人工审批节点]
  评审节点: SR2
  审批内容摘要:
    - temp_output/ 下所有已完成页面列表
    - 各页 TE 审计报告结论
    - 各页逐页人工检查结论
  相关产物: deliverables/{REQ-ID}/temp_output/*.html, deliverables/{REQ-ID}/te/temp-test-report.md
  请确认: 通过 / 驳回（请说明原因）
  ```
- 用户通过：SR2-record.md 标记 PASS，继续 Step 5
- 用户驳回：SR2-record.md 标记 FAIL，记录原因，指定需修复的页面，回退到 Step 2（该页面）

**Step 5: DE 代码合并（DEV-2）**

[PM] 调度 DE 合并所有已通过页面

5a. 写入 Handoff 文件:
- 路径: deliverables/{REQ-ID}/.handoff/to-de-merge.md
- 白名单: agents/de.md, deliverables/{REQ-ID}/temp_output/ 下所有已通过页面, deliverables/{REQ-ID}/SR2-record.md
- 输出: deliverables/{REQ-ID}/final_output/pages/ 下对应页面 + final_output/index.html

5b. 更新 .state.md: active_role=DE, status=running

5c. 发出调度指令:
```
[调度指令]
目标角色: DE
任务类型: 代码合并
Handoff 文件: deliverables/{REQ-ID}/.handoff/to-de-merge.md
输入物: deliverables/{REQ-ID}/temp_output/*.html, SR2-record.md
输出物: deliverables/{REQ-ID}/final_output/pages/*.html, deliverables/{REQ-ID}/final_output/index.html
参考: skills/dev-test.md
```

合并规则：
- 将 temp_output/*.html 复制到 final_output/pages/
- 修正页面中的资源引用路径（shared/ → ../shared/）
- 将 templates/shared/ 复制到 final_output/shared/
- **index.html 更新策略：**
  - 如果本次有新增或删除页面（页面列表变化）：基于 templates/index-skeleton.html 重新生成 final_output/index.html
  - 如果仅修改已有页面内容（页面列表不变）：不更新 index.html
  - 判断依据：对比 final_output/pages/ 中已有文件列表与本次 temp_output/ 文件列表
- 更新 .state.md: 追加已完成步骤，active_role=PM

**Step 6: TE 最终审计（TEST-2）**

[PM] 调度 TE 最终审计所有页面

6a. 写入 Handoff 文件:
- 路径: deliverables/{REQ-ID}/.handoff/to-te-final-audit.md
- 白名单: agents/te.md, deliverables/{REQ-ID}/final_output/ 下所有页面, deliverables/{REQ-ID}/te/testcases.md, templates/test-report-template.md
- 输出: deliverables/{REQ-ID}/te/final-test-report.md

6b. 更新 .state.md: active_role=TE, status=running

6c. 发出调度指令:
```
[调度指令]
目标角色: TE
任务类型: 最终审计验证
Handoff 文件: deliverables/{REQ-ID}/.handoff/to-te-final-audit.md
输入物: deliverables/{REQ-ID}/final_output/*.html
输出物: deliverables/{REQ-ID}/te/final-test-report.md
参考: skills/post-verify.md
```
- 更新 .state.md: 追加已完成步骤，active_role=PM

**Step 7: 功能评审（SR3）— 人工审批**

[PM] 进入 SR3 人工审批

- 基于 templates/sr-record-template.md 创建 deliverables/{REQ-ID}/SR3-record.md
- 填写「功能验证检查（SR2/SR3 专用）」段落：逐页记录最终审计结果
- 向用户呈现（使用人工审批呈现格式）：
  ```
  [人工审批节点]
  评审节点: SR3
  审批内容摘要:
    - final_output/ 下所有页面列表
    - TE 最终审计报告结论
    - index.html 导航完整性
  相关产物: deliverables/{REQ-ID}/final_output/pages/*.html, deliverables/{REQ-ID}/final_output/index.html, deliverables/{REQ-ID}/te/final-test-report.md
  请确认: 通过 / 驳回（请说明原因）
  ```
- 用户通过：SR3-record.md 标记 PASS，流程完成
- 用户驳回：SR3-record.md 标记 FAIL，记录原因，回退修复

**完成输出**
```
[/ppt-apply 完成]
需求编号: {REQ-ID}
产物:
  - deliverables/{REQ-ID}/final_output/*.html
  - deliverables/{REQ-ID}/te/final-test-report.md (PASS)
  - deliverables/{REQ-ID}/SR3-record.md (PASS)
下一步: 用户输入 /ppt-archive
```

---

## /ppt-archive 流程

### 触发条件
用户输入 `/ppt-archive`

### 执行序列

**Step 1: 前置检查**
- 执行 `bash src/scripts/archive.sh`
- 如果 FAIL：向用户报告失败原因，终止
- 如果 PASS：继续
- 检测当前模式：spec/ 下是否已有文件
  - 有 → 变更归档模式（merge）
  - 无 → 首次归档模式（copy）

**Step 2: 需求归档（ARC-1）**
- **首次模式：** cp deliverables/{REQ-ID}/sa/requirement-spec.md → spec/requirement-spec.md
- **变更模式：** 将 deliverables/{REQ-ID}/sa/requirement-spec.md 中的变更内容 merge 到 spec/requirement-spec.md（保留原有内容，追加/修改变更部分，标注变更来源 REQ-ID）
- 自检：文件存在 + 非空

**Step 3: 设计归档（ARC-2）**
- **首次模式：** cp deliverables/{REQ-ID}/sa/design.md → spec/design.md
- **变更模式：** 将 deliverables/{REQ-ID}/sa/design.md 中的变更内容 merge 到 spec/design.md（新增页面追加到页面清单，修改页面更新对应段落，删除页面标记移除）
- 自检：文件存在 + 非空

**Step 4: 代码归档（ARC-3）**
- cp deliverables/{REQ-ID}/final_output/pages/*.html → output/final/pages/
- cp deliverables/{REQ-ID}/final_output/shared/ → output/final/shared/（如已存在则更新）
- **index.html 更新策略：**
  - 如果本次有新增或删除页面（output/final/pages/ 文件列表变化）：基于 deliverables/{REQ-ID}/final_output/index.html 更新 output/final/index.html
  - 如果仅修改已有页面内容（页面列表不变）：不更新 output/final/index.html
- 自检：所有页面文件存在 + index.html 链接有效 + shared/ 资源完整

**Step 5: 更新状态**
- 更新 deliverables/{REQ-ID}/.state.md: phase=done
- 追加日志到 process.log

**Step 6: 项目结项确认（SR4）**
- 基于 templates/sr-record-template.md 创建 deliverables/{REQ-ID}/SR4-record.md
- 向用户呈现（使用人工审批呈现格式）：
  ```
  [人工审批节点]
  评审节点: SR4
  审批内容摘要:
    - 归档模式：首次归档 / 变更归档
    - 归档文件列表
    - 变更模式下：本次变更涉及的页面、基线版本号
    - 最终产物入口：output/final/index.html
  相关产物: spec/requirement-spec.md, spec/design.md, output/final/index.html, output/final/pages/*.html
  请确认: 通过 / 驳回（请说明原因）
  ```
- 用户通过：SR4-record.md 标记 PASS，项目结项
- 用户驳回：SR4-record.md 标记 FAIL，记录原因，回退修复

**完成输出**
```
[/ppt-archive 完成]
需求编号: {REQ-ID}
模式: {首次归档/变更归档}
归档产物:
  - spec/requirement-spec.md (已{创建/merge})
  - spec/design.md (已{创建/merge})
  - output/final/*.html
  - output/final/index.html
基线版本: spec/baselines/*.v{N}.md
项目状态: DONE
```
