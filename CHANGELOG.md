# PPT-Harness 需求变更日志

本文件记录用户提出的所有问题点及对应解决方案，按时间倒序排列。

---

## 2026-05-15

### DE 误写根目录 output/final/ 而非 deliverables/{REQ-ID}/output/pages/

**问题：** apply 阶段 DE 开发页面时，直接修改了根目录下的 output/final/ 内容，而不是写入 deliverables/{REQ-ID}/output/pages/。output/final/ 是归档后的只读目录，只有 /ppt-archive 才能操作。

**原因：** 多个文件中使用了缩写路径 `output/pages/`（缺少 `deliverables/{REQ-ID}/` 前缀），DE 可能将其误解为根目录下的 output/ 路径。agents/de.md 的禁止事项中也没有显式禁止写入 output/final/。

**方案：**
- agents/de.md：禁止事项新增"禁止写入根目录 output/final/"，协作接口路径补全前缀
- skills/dev-test.md：断点续作和完成标志中的路径补全 `deliverables/{REQ-ID}/` 前缀
- CLAUDE.md / .clinerules：产物纪律新增"DE 开发阶段只能写入 deliverables/{REQ-ID}/output/pages/，绝对禁止写入根目录 output/final/"

---

### SR2/SR3 record 文件未生成（再次发生）

**问题：** REQ004 开发流程中，PM 跳过了 SR2-record.md 和 SR3-record.md 的创建步骤，直接完成了归档。虽然 workflow.md 中已有创建指引，但缺乏硬校验拦截。

**方案：** 在 archive.sh 前置检查中增加硬校验：
- SR2-record.md 必须存在且包含 PASS 标记
- SR3-record.md 必须存在且包含 PASS 标记
- 任一不满足则 FAIL，阻止归档流程继续

这样即使 PM 跳过了创建步骤，archive 阶段也会被脚本拦截，强制回去补齐。

---

### apply 结束后未提示下一步操作

**问题：** /ppt-apply 流程结束后，PM 没有打印完成通知，也没有提醒用户接下来需要执行 /ppt-archive。用户不知道流程已结束。

**方案：**
- workflow.md 中 /ppt-apply「完成输出」增加 ⚠️ 强制标记，明确 PM 不得省略
- CLAUDE.md / .clinerules 流程纪律新增规则：每个流程结束时必须打印「完成输出」模板，告知用户下一步操作

---

### 逐页人工检查强制执行机制

**问题：** apply 阶段要求每个页面都经过人工检查，但实际执行中 PM 经常只对第一个页面 P01 做人工检查，之后跳过直接进入 SR2。缺乏硬性约束保证每页都走人工确认。

**方案：** 组合方案——前置任务编排 + 逐页状态追踪：
1. apply 开始时新增 Step 1b「任务编排确认」：PM 生成完整开发计划（列出每个页面的 DE→TE→人工检查步骤），用户确认后才开始开发循环。用户可以直观看到每页都有人工检查环节。
2. .state.md 新增「逐页人工检查记录」表：每页人工检查通过后 PM 必须追加 PASS 记录。
3. PM 写入下一页 Handoff 前必须校验上一页有 PASS 记录，否则禁止继续。
4. 断点恢复时通过该记录判断哪些页面已完成人工确认。

改动涉及：
- workflow.md：新增 Step 1b 任务编排确认，Step 2 增加前置校验，Step 3b 增加记录写入
- templates/state-template.md：新增「逐页人工检查记录」表
- CLAUDE.md / .clinerules：新增「逐页人工检查强制执行」规则段落

---

### 移除 temp_output 中间目录

**问题：** 开发过程中 DE 写入 temp_output/，但该目录没有 shared/ 资源（CSS/JS/图标），导致人工检查时打开页面看到的是样式缺失的效果，无法正确校验。

**方案：** 完全去掉 temp_output 中间目录，DE 直接写入 output/pages/。同时删除 DEV-2 合并步骤（不再需要）。改动涉及：
- workflow.md：DE 输出改为 output/pages/，删除 Step 5 DEV-2 合并，步骤重新编号
- init-task.sh：创建 output/pages/ 和 output/shared/ 代替 temp_output/
- resume-check.sh：只检查 output/pages/ 下文件
- verify.sh：A类和C类检查改为扫描 output/pages/
- playwright-check.sh：示例路径更新
- agents/de.md：输出契约改为 output/pages/，移除合并相关
- agents/te.md：审计路径改为 output/pages/
- skills/dev-test.md、post-verify.md：路径更新
- templates/design-template.md、testcases-template.md、test-report-template.md：路径更新
- README.md：/ppt-apply 表格删除 DEV-2 行，路径更新
- _dev/doc/design.md：流程图和目录结构更新

首页开发前环境准备（仅首个页面时执行一次）：将 templates/shared/ 复制到 output/shared/，生成 index.html。

---

### 人工检查不应有轮次限制

**问题：** 逐页人工检查驳回时也使用了 round_count+1 逻辑，暗示有5轮限制。5轮限制只针对 TE 自动审计失败，人工检查驳回用户想改多少次就改多少次。

**方案：** 修改 workflow.md Step 3b：移除人工检查驳回时的 round_count+1，明确标注"人工检查驳回无轮次限制"。循环描述中也区分：TE 审计"最多5轮，超过上升人工"，人工检查"无轮次限制"。

---

### index.html 不必要更新

**问题：** 每次提一个小需求（只改一个页面内容），系统总是把 index.html 也一起更新了，而不是只更新目标页面。

**方案：** 在 workflow.md 的 DEV-2 合并规则和 ARC-3 归档步骤中增加 index.html 更新策略：只有页面列表变化（新增/删除页面）时才重新生成 index.html，仅修改已有页面内容时不动它。判断依据为对比已有文件列表与本次输出文件列表。

---

### SR3-record.md 未被创建

**问题：** /ppt-apply 最后阶段 SR3 通过后，SR3-record.md 文件没有被正确创建。

**方案：** workflow.md 中 SR3 步骤描述过于简略（只写了"填写 SR3-record.md"），缺少创建路径和操作细节。补充为与 SR2 相同的完整指引：基于模板创建文件 → 填写审计段落 → 标准审批呈现格式 → PASS/FAIL 标记。同时检查 SR1 和 SR4 也有类似问题，一并修复。

---

### init-task.sh 语法报错

**问题：** `bash src/scripts/init-task.sh` 执行报错：`line 28: syntax error near unexpected token '2'`。

**方案：** `for ... in` 语句中不能直接使用 `2>/dev/null` 重定向。移除 for 循环中的 `2>/dev/null`，依靠下一行 `[ -f "$STATE_FILE" ] || continue` 处理 glob 不匹配的情况。

---

### 归档后 phase 未设为 done

**问题：** /ppt-archive 归档成功后，.state.md 的 phase 被设为 "archived" 而非 "done"，导致下次 /ppt-init 误判为未完成需求（RESUME 模式）。

**方案：** 修改 init-task.sh，让场景检测同时识别 "done" 和 "archived" 为已完成状态。三处改动：RESUME 检测条件、CHANGE 模式已完成计数、用户提示信息。

---

### Handoff 协议设计文档补充

**问题：** design.md 中 3.3 节 Handoff 协议描述过于简略，不足以让人理解完整运作方式。

**方案：** 扩充为完整设计文档，包含：设计动机、运作流程（PM调度→角色执行→PM验证）、核心机制详解（Handoff文件/状态文件/上下文围栏/断点恢复）、文件命名规范表、关键约束汇总表、涉及文件清单。

---

### 场景检测/变更模式沉淀到文档

**问题：** 三场景检测（NEW/RESUME/CHANGE）、变更模式、基线备份、merge归档、输出子目录等新特性未记录到文档。

**方案：** 更新三个文档：
- `_dev/doc/requirements.md`：新增第九节（场景检测与变更模式）、第十一节（输出目录结构），更新视觉风格和页面规范
- `_dev/doc/design.md`：修订 4.2（init三场景）、4.5（archive merge）、5.1（深色调色板）、5.4（自由布局）、第八节（目录结构）、9.2（断点续作）
- `README.md`：同步更新视觉风格、Step 1/4、附录1、触发表、目录结构

---

## 2026-05-15（早期）

### SR2 流程理解纠正

**问题：** 对 SR2 流程理解错误。正确逻辑是：每一页都需要经过 DE开发→TE审计→人工检查 循环，所有页面完成后再统一进行 SR2 正式审批。

**方案：** 重写 workflow.md 的 /ppt-apply 流程：Step 2-3 为逐页循环体（DE→TE→人工检查），循环结束后 Step 4 为 SR2 正式审批，Step 5-7 为合并→最终审计→SR3。同步更新 CLAUDE.md、.clinerules、README.md、requirements.md、design.md。

---

### 视觉效果差 - 过度约束

**问题：** 制作出来的 PPT 排版和内容显示效果一般，怀疑是项目中对排版显示的强制要求太多，限制了大模型发挥。

**方案：** 诊断为过度约束（固定三段式、卡片数量检查、3x3深度原则）。针对性放松：移除三段式强制、移除卡片数量/li数量检查，保留容器尺寸和基本结构要求。DE 获得完全布局自由。

---

### 连续相同布局 + 纯文本页面

**问题：** 1）相邻页面布局重复 2）页面全是纯文本，没有图形元素。

**方案：** 增加两条强制规则：相邻页面禁止使用相同布局（追求视觉节奏感）；每页需有图形元素（图标/图表/插图），禁止纯文本页面。

---

### 图标按需下载

**问题：** 图标能否用到的时候再下载，不要全量下载？

**方案：** 使用 Lucide Icons CDN 按需下载单个 SVG 文件到 templates/shared/icons/，DE 开发时根据页面需要下载对应图标，不预装全量图标库。

---

### 键盘导航与渐进揭示

**问题：** 强制要求每个 Page 支持方向键导航，且如果页面有分步内容，优先控制步骤显示/隐藏。

**方案：** 重写 nav.js 支持 .step 类渐进揭示：→/↓ 优先显示下一步，步骤全部显示后才翻页；←/↑ 优先隐藏上一步，第一步时才翻回上页。Esc 返回索引。CSS 增加 .step/.step-visible 样式。

---

### 设计约束应沉淀到 skill 文件

**问题：** CLAUDE.md 内容太多，视觉设计约束应该统一沉淀到一个 design-skill 里面。

**方案：** 创建 skills/design-visual.md 作为视觉设计规范的单一来源（色彩/字体/布局/内容逻辑/图形元素/分步展示/资源路径/图标下载/图片下载）。CLAUDE.md 只保留一行引用。SA 和 DE 开发设计时加载该 skill。

---

### 变更迭代支持

**问题：** 首次制作完成后，第二次 /ppt-init 会全部重新分析所有历史需求，而不是只讨论变更点。同时需要支持断点续作和基线备份管理。

**方案：** 设计三场景检测机制：
- NEW：全新项目，完整需求澄清
- RESUME：未完成需求，提示继续
- CHANGE：变更模式，自动备份基线到 spec/baselines/*.vN.md，需求澄清仅围绕变更点
归档时 merge 而非覆盖。init-task.sh 实现自动检测逻辑。

---

### 输出目录结构优化

**问题：** 页面数量多时，所有文件平铺在一个目录不合理，建议子页面放子目录。

**方案：** 重构输出目录：output/final/index.html（首页）+ output/final/pages/（章节页面）+ output/final/shared/（资源）。nav.js 的 goToIndex() 适配 pages/ 子目录路径。

---

## 2026-05-14

### 角色隔离不够强 - Handoff 协议

**问题：** PM/SA/DE/TE 四个角色共享同一对话上下文，角色可能"串戏"——引用其他角色的推理过程，导致角色隔离形同虚设。

**方案：** 实现"纯文件协议 + 强化行为约束"方案：
- 创建 templates/handoff-template.md（任务描述 + 文件白名单 + 期望输出 + 约束 + 轮次信息）
- 创建 templates/state-template.md（phase/active_role/status/已完成步骤/审批记录）
- PM 每次调度前必须写入 Handoff 文件 + 更新 .state.md
- 非 PM 角色仅读取白名单文件，禁止引用对话历史
- 每个 skill 文件顶部增加「上下文围栏」强制约束段落
- init-task.sh 创建 .handoff/ 目录和 .state.md
- check-harness.sh 增加模板文件和协议段落的硬校验

---

### PM 调度过程不透明

**问题：** PM 调度各角色时没有可观测的过程记录，出问题后难以追溯是哪个环节失败。

**方案：** 增加两个机制：
- PM 心跳：每次调度前打印 `[PM] {描述}`，覆盖调度、验证、审批、异常等时机
- 过程日志：所有角色执行过程记录到 deliverables/{REQ-ID}/process.log，格式 `[{时间}] [{角色}] {事件描述}`
- PM 调度前/验证后各写一条，SA/DE/TE 完成后写一条，审批和异常各写一条

---

### 断点恢复依赖对话历史

**问题：** 上下文重置或新会话后，PM 无法准确恢复到之前的执行进度，依赖对话历史推断进度不可靠。

**方案：** 设计断点恢复协议：
- PM 恢复时仅读取 .state.md 确定恢复点
- 根据 phase + active_role + status 判断：status=running 且输出已存在→视为完成；输出不存在→重新发起
- 禁止依赖对话历史推断进度
- apply 阶段通过 resume-check.sh 识别已完成页面自动跳过

---

### 项目初始骨架搭建

**问题：** 需要从零搭建整个 PPT-Harness 系统的基础设施。

**方案：** 按四层递进防线架构搭建：
- Rules 层：CLAUDE.md + .clinerules（全局纪律，跨平台同源）
- Skills 层：5 个 skill 文件（init-clarify/propose/dev-test/post-verify/spec-merge）
- Agents+Workflow 层：4 个 agent 定义（pm/sa/de/te）+ workflow.md 调度手册
- Scripts 层：init-task.sh/propose.sh/apply.sh/archive.sh/verify.sh/baseline.sh/resume-check.sh/check-harness.sh
- 模板层：proposal/requirement-spec/design/testcases/test-report/sr-record/page-skeleton/index-skeleton
- 共享资源：styles.css + nav.js + mermaid-init.js
- MCP 配置：zai-mcp-server + web-search-prime + web-reader
