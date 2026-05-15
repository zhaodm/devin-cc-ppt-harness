# PPT-Harness - 教材制作系统

本项目是一个高度可移植、Agent驱动的教材制作系统。实现从课程纲要到高质量16:9 HTML 演示文稿的自动化生产。

本项目**主要目的是节省人员宝贵的时间，无需花费时间在ppt版式美化/制作各种图表等工作上面，只需要用文字表达清楚自己汇报的主题/目标、逻辑思维、数据支撑等**

---

## 1、架构：四层递进防线

四层防线按**约束力由弱到强**递进排列。每一层专门弥补上一层的固有缺陷：

### 第一层：Rules -- 行为约束

**解决问题：** Agent最常犯的低级错误----修改后无基础自检、擅自改动上游制品。

**实现方式：** 1个md文件，约束全局纪律。**一定要精简**。

**固有局限：** Rules本质是自然语言指令，Agent对其的遵守程度随上下文复杂度增加而下降。无法保证100%执行。

### 第二层：Skills -- 标准操作规程

**解决问题：** 具体操作步骤由 Agent 临场发挥，行为发散导致结果的不可预测性提升。

**实现方式：** 5 个 Skill 文件，每个封装一套固定步骤的 SOP（标准操作规程）。所有重复性操作不依赖 Agent 记忆。

**设计原则：** Rule 定义"什么必须做"，Skill 定义"具体怎么做"。二者分离后，Rule 保持简洁，Skill 承载执行细节。

### 第三层：Agents + Workflow -- 角色制衡

**解决问题：** 单一 Agent 自审的结构性失效。写需求的人不应该同时审需求，写代码的人不应该同时做终验。

**实现方式：** 4 个 Agent 角色，每个具有独立的契约定义（输入/输出/阻塞条件/禁止事项），通过固定编排的 Workflow 接力执行。

**固有局限：** 角色和流程仍属于"指令层"约束，Agent 声称"已完成"时缺少独立的客观验证手段。

### 第四层：Scripts + 人工 -- 硬校验

**解决问题：** 前三层仍属于指令层约束，Agent 声称"已完成"时缺少机器化验证。

**实现方式：** 3 个硬校验脚本以退出码作为唯一判据—— verify.sh（A/B/C 三类检查点）、baseline.sh（前后对比）、check-harness.sh（框架自检）。另每次交付一个页面都必须由人工审核通过再进行下个页面的编写。

**设计原则：** 交付判定不依赖 Agent 自述，依赖程序退出码。

### 递进关系，非替代关系

Rule设定约束 --> Skill标准化执行 --> Agent角色制衡 --> Script硬性校验。每一层专门弥补上一层的固有缺口，四层合并形成闭环。



## 2、四个Agent角色

角色拆分源于研发流程中的具体问题，而非预设的组织架构：

#### PM - 项目经理

流程调度中枢。读结论、发任务、处理回退、执行Spec Merge。不参与需求定义、方案设计或技术判断。

#### SA -- 方案架构师

将模糊需求转化为SHALL + GWT格式的结构化需求，将结构化需求翻译为技术方案。包含需求-->技术落实对照表、时序图、Tasks清单。

#### DE -- 开发工程师

强制TDD模式：编写测试（FAIL）-->实现代码（PASS）-->重构-->执行dev-test Skill-->执行post-verify Skill。

#### TE -- 测试工程师

交付链的最终验收环节。执行3类测试（浏览器E2E/回归/工程验证），浏览器E2E类测试必须使用真实浏览器。

#### Agent契约结构

每个Agent定义文件内嵌完整的角色契约：身份-->职责-->输入-->输出-->阻塞条件-->禁止事项-->模型建议。一个文件即一个角色的完整规范，维护不分散。



## 3、研发流程：需求澄清 + 三段式接力 + 人工审批

完整研发流程按触发命令划分为四个分段：init（人机协作打磨 Proposal）、propose（自动化需求→方案→评审）、apply（自动化开发→审查→测试→待归档）、archive（人工确认触发 Spec Merge + 归档）。

流程设有两道人工审批：SA方案设计后、TE测试验证PASS后。每个阶段骨架如下：

**/ppt-init**
`init-task.sh → 人机协作打磨 proposal.md → 消除歧义 + 定稿`

**/ppt-propose**
`SA 需求分析&方案设计 → 人工审批 1`

**/ppt-apply**
`DE TDD 开发 → TE 审计验证 → 人工审批 2`

**/ppt-archive**
`✓ Spec Merge + mv 归档 + board DONE`

---

**顺序约束1：**必须按序，前序未完成不得执行后序命令。

**顺序约束2：** 每一小步骤之间都必须由PM进行调度，一个小步骤结束后返回给PM，由PM对输出进行检查，检查通过启动下一步。

> **列说明**
>
> - **步骤ID**：workflow YAML 中的 step_id，WE 调度的最小单元
> - **执行角色**：负责完成该步骤的 Agent
> - **上游输入**：该步骤启动前必须通过校验的产出物
> - **交付输出**：该步骤写入 spec 的产出物

---

### /ppt-propose

| 步骤ID | 活动名称     | 执行角色 | 上游输入                                   | 交付输出                                                     |
| ------ | ------------ | -------- | ------------------------------------------ | ------------------------------------------------------------ |
| REQ-1  | 需求分析     | SA       | `reference/`<br>`deliverables/proposal.md` | `deliverables/sa/requirement-spec.md`                        |
| REQ-2  | 架构设计     | SA       | `deliverables/sa/requirement-spec.md`      | `deliverables/sa/design.md`                                  |
| REQ-3  | 测试用例设计 | TE       | `deliverables/sa/requirement-spec.md`      | `deliverables/te/testcases.md`                               |
| SR1    | **需求评审** | PM       | `deliverables/sa/`<br>`deliverables/te/`   | `deliverables/SR1-record.md`<br>`deliverables/baselines/requirement-spec.v1.md`<br>`deliverables/baselines/design.v1.md`<br>`deliverables/baselines/testcases.v1.md` |

---

### /ppt-apply

**顺序约束3：**TE进行审计，如果发现问题，将审计结果和相关日志返回给PM，PM判断审计失败，再将相关信息发给DE去修复问题，再进行下一轮审计，轮次最大次数限制在5次，如果超过5次必须上升到人工审核。

| 步骤ID | 活动名称     | 执行角色           | 上游输入                                                     | 交付输出                                                     |
| ------ | ------------ | ------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| DEV-1  | 编码实现     | DE                 | `deliverables/sa/design.md`                                  | `deliverables/output/pages/xx`<br/>`deliverables/de/code-report.md` |
| TEST-1 | 审计验证     | TE                 | `deliverables/output/pages/xx`                         | `deliverables/te/temp-test-report.md`                        |
| SR2    | **功能评审** | PM（人机交互决策） | `deliverables/output/pages/xx`<br>`deliverables/te/temp-test-report.md` | `deliverables/SR2-record.md`                                 |
| TEST-2 | 审计验证     | TE                 | `deliverables/output/pages/xx`                         | `deliverables/te/final-test-report.md`                       |
| SR3    | **功能评审** | PM（人机交互决策） | `deliverables/output/pages/xx`<br>`deliverables/te/final-test-report.md` | `deliverables/SR3-record.md`                                 |

---

### /ppt-archive

| 步骤ID | 活动名称         | 执行角色           | 上游输入                              | 交付输出                   |
| ------ | ---------------- | ------------------ | ------------------------------------- | -------------------------- |
| ARC-1  | 需求归档         | PM                 | `deliverables/sa/requirement-spec.md` | `spec/requirement-spec.md` |
| ARC-2  | 设计归档         | PM                 | `deliverables/sa/design.md`           | `spec/design.md`           |
| ARC-3  | 代码归档         | PM                 | `deliverables/output/xx`        | `output/final/xx`          |
| SR4    | **项目结项确认** | PM（人机交互决策） |                                       |                            |

---



## 4、运行环境与使用方式

### 支持平台
- Claude Code CLI（终端）
- VSCode Cline 插件
- VSCode Claude Code 插件对话框

三个平台共享同一套核心逻辑，通过 `CLAUDE.md`（Claude Code）+ `.clinerules`（Cline）实现规则同源，`.mcp.json` 统一 MCP 配置。

### 前置准备

1. **环境要求**：Node.js 18+、npm
2. **配置 API Key**：设置环境变量 `Z_AI_API_KEY`（智谱 BigModel API Key）
3. **准备纲要文件**：将课程纲要（md/txt/图片）放入 `reference/` 目录

### 用户操作步骤

**Step 1: 需求初始化与澄清**

在对话框输入：
```
/ppt-init
```

系统行为：
- 自动检测场景：
  - **NEW**：无历史需求，全新项目
  - **RESUME**：检测到未完成的 REQ，提示用户继续或放弃
  - **CHANGE**：有已完成的历史需求，进入变更模式（自动备份基线）
- 首次运行自动安装 Playwright 依赖
- NEW/CHANGE 模式：创建新 REQ-ID 目录，进入需求澄清
- 变更模式下仅讨论变更点，不重复已有内容
- PM 逐轮提问（每轮≤3题），生成 Proposal 草稿供确认
- 用户确认通过后，Proposal 定稿

**Step 2: 需求分析与方案设计**

在对话框输入：
```
/ppt-propose
```

系统行为：
- SA 执行需求分析，生成结构化需求文档
- SA 执行架构设计，生成页面设计方案
- TE 设计测试用例
- PM 汇总后呈现人工审批（SR1）
- 用户审批通过后进入下一阶段；驳回则回退修改

**Step 3: 开发与审计**

在对话框输入：
```
/ppt-apply
```

系统行为：
- 逐页循环开发（DE 编码 → TE 浏览器审计 → 人工检查确认该页OK，最多5轮修复）
- 所有页面开发+审计+人工检查完成后，统一进行 SR2 正式审批
- SR2 通过后 DE 合并到最终产物，TE 最终审计
- 最终审计通过后呈现 SR3 人工审批
- 支持断点续作：中断后重新输入 `/ppt-apply` 自动跳过已完成页面

**Step 4: 归档结项**

在对话框输入：
```
/ppt-archive
```

系统行为：
- 检测归档模式：
  - **首次归档**（spec/ 为空）：直接复制需求、设计、代码到归档目录
  - **变更归档**（spec/ 已有文件）：将变更内容 merge 到现有 spec 文件
- 将代码归档到 output/final/（index.html + shared/ + pages/）
- 生成/更新 index.html 索引页
- 呈现归档摘要供用户确认结项（SR4）

**查看最终成果**

归档完成后，在浏览器中打开：
```
output/final/index.html
```

支持键盘导航：← → 翻页（含 .step 渐进揭示），Esc 返回索引。

### 用户触发方式

用户在对话框中输入斜杠命令触发流程，Agent 自动识别并按对应 Skill 执行：

| 命令 | 触发行为 |
|------|---------|
| `/ppt-init` | 场景检测（NEW/RESUME/CHANGE）+ 创建任务目录 + 进入需求澄清 |
| `/ppt-propose` | 前置检查 → SA需求分析 + 架构设计 → TE测试用例 → PM评审 |
| `/ppt-apply` | 前置检查 → DE逐页开发 → TE浏览器审计 → 逐页人工检查 → SR2 → 合并 → SR3 |
| `/ppt-archive` | 前置检查 → 产物归档（首次copy/变更merge）→ 用户确认结项 |

### MCP 工具集

| 服务 | 用途 | 调用时机 |
|------|------|---------|
| zai-mcp-server | 图片内容识别 | reference/ 含图片时 |
| web-search-prime | 联网搜索补充资料 | SA 研究阶段 |
| web-reader | 网页内容抓取 | 用户提供参考链接时 |

---

## 5、视觉风格

采用 **深色专业风格 + 高信息密度** 的组合：

- 深蓝灰底色（#1e2a3a）、白色主文字（#ffffff）
- 辅助色（#c8d6e5）、橙色强调（#e67e22）
- 正文字号 18px 起步，高可读性
- 每页需有图形元素（图标/图表/插图），禁止纯文本页面
- 相邻页面禁止使用相同布局，追求视觉节奏感
- 图标使用 Lucide Icons，按需从 CDN 下载 SVG
- 完整视觉规范详见 `skills/design-visual.md`

---

## 6、实施阶段

| 阶段 | 目标 | 内容 |
|------|------|------|
| 第一阶段 | 骨架搭建 | 目录结构、Rules、Agent契约、Skill骨架、脚本入口、HTML模板骨架 |
| 第二阶段 | 流程贯通 | Skill执行细节、Workflow串联、硬校验脚本（verify/baseline/check-harness） |
| 第三阶段 | 质量打磨 | 模板精修、Playwright接入、断点续作、Token节流、键盘导航 |

---

## 附录1. 特别约束

- **每个章节作为单独的html页面**：放在 `output/final/pages/` 子目录中，通过 `output/final/index.html` 将各个章节串起来，做好章节之间的跳转逻辑。每个章节可以独立交付。

- **每个页面在TE审计通过后，需经过逐页人工检查确认。所有页面完成后，统一进行 SR2 正式审批，通过后才可合并到最终产物。**

- **每一页TE必须通过真实浏览器（可以选择Playwright）检查显示效果。**

- **断点续作与 Token 节流**: 支持三场景检测（NEW/RESUME/CHANGE）；RESUME 模式自动恢复未完成任务；每完成一页清洗上下文代码记忆。

- **变更迭代支持**: CHANGE 模式自动备份基线到 `spec/baselines/`，需求澄清仅围绕变更点，归档时 merge 而非覆盖。

- **键盘导航与渐进揭示**: ←/↑ 返回上一页（或上一步），→/↓ 前进下一页（或下一步），Esc 返回索引。支持 `.step` 类分步展示。

  

## 附录2. 页面排版规范 (Page Standards)

每一页必须在 16:9 容器（1280×720px）内呈现，页面内部结构由 DE 自主设计，鼓励多样化布局：

- **不强制每页都用三段式**（标题→金句→主体），DE 可根据内容选择最佳呈现方式
- 可选布局风格：英雄大图+标题、左右分栏、时间线、数据仪表盘、对比表格、引用金句页、流程图解、卡片网格等
- 同一份 PPT 中相邻页面应避免使用相同布局，追求视觉节奏感
- 每页必须有明确标题（h1 或等效），内容信息完整不遗漏
- 建议遵循深度原则：每个信息块包含结论 + 支撑细节，避免空洞罗列



## 附录3. 目录结构 (Directory Structure)

```text
ppt-harness/
├── CLAUDE.md              # Claude Code 规则
├── .clinerules            # Cline 规则（同源）
├── .mcp.json              # MCP 配置
├── .gitignore             # Git 忽略规则
├── package.json           # Playwright 依赖
├── agents/                # 智能体指令定义
│   ├── pm.md              # 总调度
│   ├── sa.md              # 构思专家
│   ├── de.md              # 制作专家
│   └── te.md              # 审计专家
├── skills/                # 模块化技能集
│   ├── init-clarify.md
│   ├── propose.md
│   ├── dev-test.md
│   ├── post-verify.md
│   ├── spec-merge.md
│   └── design-visual.md  # 视觉设计规范（SA/DE 参考）
├── src/                   # 执行与调度引擎
│   ├── workflow.md        # PM 调度手册
│   ├── core/              # 核心逻辑
│   ├── scripts/           # CLI 入口脚本
│   └── playwright/        # E2E 测试脚本
├── templates/             # HTML 视觉模板
│   ├── shared/            # 共享 CSS/JS
│   │   ├── styles.css
│   │   ├── nav.js
│   │   ├── mermaid-init.js
│   │   ├── icons/         # Lucide 图标（按需下载）
│   │   └── images/        # 图片资源
│   ├── layouts/           # 布局变体
│   └── *.md / *.html      # 文档与页面模板
├── reference/             # 输入纲要存放处（用户放入）
├── deliverables/          # 过程产物（按 REQ-ID 分目录，运行时生成）
├── spec/                  # 归档需求与设计（运行时生成）
│   └── baselines/         # 历史基线备份（变更迭代时自动生成）
└── output/                # 最终产物
    └── final/
        ├── index.html     # 首页/目录
        ├── shared/        # CSS/JS/图标/图片
        └── pages/         # 所有章节页面
```

