# PPT-Harness 系统设计文档

---

## 一、系统概述

PPT-Harness 是一个 Agent 驱动的教材制作系统，通过四层递进防线架构，实现从课程纲要到 16:9 HTML 演示文稿的自动化生产。系统跨平台兼容 Claude Code CLI、VSCode Cline 插件和 VSCode Claude Code 插件。

---

## 二、架构设计

### 2.1 四层递进防线

```
第一层 Rules（行为约束）
  ↓ 弥补：Agent 低级错误
第二层 Skills（标准操作规程）
  ↓ 弥补：行为发散
第三层 Agents + Workflow（角色制衡）
  ↓ 弥补：自审失效
第四层 Scripts + 人工（硬校验）
```

| 层级 | 实现文件 | 解决问题 |
|------|---------|---------|
| Rules | CLAUDE.md, .clinerules | 全局纪律约束 |
| Skills | skills/*.md (5个) | 标准化执行步骤 |
| Agents+Workflow | agents/*.md + src/workflow.md | 角色隔离与流程编排 |
| Scripts+人工 | src/scripts/*.sh + 人工审批 | 机器化验证 + 人工决策 |

### 2.2 跨平台兼容方案

```
Claude Code CLI  → 读取 CLAUDE.md
VSCode Cline    → 读取 .clinerules
VSCode Claude   → 读取 CLAUDE.md
共享            → .mcp.json（MCP 配置）
```

三个平台共享同一套核心逻辑，规则文件内容同源。

---

## 三、角色设计

### 3.1 角色职责矩阵

| 角色 | 职责 | 禁止事项 |
|------|------|---------|
| PM | 调度、检查、人机交互 | 技术判断、开发、设计、测试 |
| SA | 需求分析、架构设计 | 开发编码、调度 |
| DE | 编码实现（TDD） | 设计、需求定义、调度 |
| TE | 审计验证（Playwright） | 开发、设计、调度 |

### 3.2 角色契约结构

每个 Agent 定义文件（agents/*.md）包含：
- 身份（Identity）
- 职责（Responsibilities）
- 输入契约（Input Contract）
- 输出契约（Output Contract）
- 阻塞条件（Blocking Conditions）
- 禁止事项（Prohibitions）
- 协作接口（Collaboration Interface）

### 3.3 Handoff 协议（角色隔离强化）

**设计动机：** PM/SA/DE/TE 四个角色共享同一对话上下文，角色可能"串戏"（引用其他角色的推理）。Handoff 机制通过结构化文件协议 + 上下文围栏，在不依赖子 Agent API 的前提下实现虚拟角色隔离，跨平台兼容（Claude Code CLI + Cline + VSCode Claude Code）。

**运作流程：**

```
PM 调度角色前（每次必须执行）:
  ① 打印心跳: [PM] 调度 {角色} 执行 {任务}
  ② 写入 Handoff 文件 → .handoff/to-{role}-{task-slug}.md
  ③ 更新 .state.md → active_role, status, last_updated
  ④ 发出 [调度指令]（含 Handoff 文件路径）
  ⑤ 追加日志到 process.log

目标角色（SA/DE/TE）启动时:
  ① 读取 Handoff 文件，确认任务范围
  ② 仅读取白名单中的文件（禁止读取白名单外任何文件）
  ③ 禁止引用对话历史中其他角色的推理或产出
  ④ 执行任务，输出到指定路径
  ⑤ 完成后仅报告文件路径，不在对话中展开产物内容
  ⑥ 追加一条日志到 process.log

目标角色完成后，PM:
  ① 验证产出物（文件存在 + 非空 + 格式合规）
  ② 更新 .state.md（追加已完成步骤、恢复 active_role 为 PM）
  ③ 追加日志到 process.log
```

**核心机制：**

1. **Handoff 文件**（deliverables/{REQ-ID}/.handoff/to-{role}-{task}.md）
   - 使用 templates/handoff-template.md 格式
   - 包含：任务描述、文件白名单、期望输出、约束条件、参考 Skill、轮次信息
   - 白名单精确列出目标角色可读取的每一个文件路径（禁止通配符）
   - 写入后不可修改，重试时创建新文件（追加轮次后缀如 -fix-r2）

2. **状态文件**（deliverables/{REQ-ID}/.state.md）
   - 使用 templates/state-template.md 格式
   - YAML frontmatter：req_id, phase, active_role, status, current_page, pages_total, pages_done, round_count, last_updated
   - 已完成步骤审计表（时间/角色/任务/产物路径/结果）
   - 当前 Handoff 引用
   - 阻塞记录
   - 人工审批记录

3. **上下文围栏**（Context Fence）
   - 每个 skill 文件顶部的强制约束段落
   - SA/DE/TE 角色：读取角色定义 → 读取 Handoff → 白名单约束 → 忽略对话历史 → 输出隔离 → 状态更新
   - PM 角色：读取角色定义 → 读取状态文件 → 输入范围限制 → 忽略角色推理 → 状态更新
   - 违反任何一条，当前产出无效，必须重新执行

4. **断点恢复协议**
   - PM 恢复时仅读取 .state.md 确定恢复点
   - 根据 phase + active_role + status 判断：
     - status=running 且期望输出已存在 → 视为完成，继续下一步
     - status=running 且期望输出不存在 → 重新创建 Handoff 发起该步骤
   - 禁止依赖对话历史推断进度

**Handoff 文件命名规范：**

| 阶段 | 文件名 | 目标角色 |
|------|--------|---------|
| propose | to-sa-req-analysis.md | SA |
| propose | to-sa-arch-design.md | SA |
| propose | to-te-testcase-design.md | TE |
| apply | to-de-dev-p{NN}.md | DE |
| apply | to-te-audit-p{NN}.md | TE |
| apply | to-de-dev-p{NN}-fix-r{N}.md | DE（修复轮次） |
| apply | to-de-merge.md | DE |
| apply | to-te-final-audit.md | TE |

**关键约束汇总：**

| 约束 | 实现位置 |
|------|---------|
| 白名单文件访问 | Handoff 文件 + 上下文围栏 |
| 角色隔离 | 每个 skill 顶部「上下文围栏」段落 |
| 不可变性 | Handoff 写入后不修改，重试创建新文件 |
| 状态追踪 | .state.md（phase/active_role/status/pages_done） |
| 审计追溯 | process.log 记录全链路 |
| 硬校验 | check-harness.sh 验证模板文件存在 + CLAUDE.md 包含协议段落 |

**涉及文件清单：**

| 文件 | 作用 |
|------|------|
| templates/handoff-template.md | Handoff 文件格式模板 |
| templates/state-template.md | 状态追踪文件模板 |
| CLAUDE.md / .clinerules | 协议规则（全局约束，跨平台同源） |
| src/workflow.md | PM 调度手册中的详细执行序列 |
| skills/*.md | 每个 skill 顶部的上下文围栏 |
| src/scripts/init-task.sh | 创建 .handoff/ 目录和 .state.md |
| src/scripts/check-harness.sh | 验证模板和协议段落存在 |

---

## 四、流程设计

### 4.1 命令与流程映射

| 命令 | 脚本 | Skill | 产出 |
|------|------|-------|------|
| /ppt-init | init-task.sh | init-clarify.md | proposal.md |
| /ppt-propose | propose.sh | propose.md | requirement-spec.md, design.md, testcases.md |
| /ppt-apply | apply.sh | dev-test.md + post-verify.md | temp_output/*.html → final_output/*.html |
| /ppt-archive | archive.sh | spec-merge.md | spec/, output/final/ |

### 4.2 /ppt-init 流程

```
init-task.sh（场景检测）
  │
  ├─ MODE=RESUME → 提示用户继续未完成的 REQ，不创建新目录
  │
  ├─ MODE=CHANGE → 备份 spec/ 到 spec/baselines/*.vN.md
  │                → 创建新 REQ-ID + 目录 + .state.md + .handoff/
  │                → 需求澄清仅围绕变更点（读取现有基线作参考）
  │                → 生成 proposal.md（状态 READY）
  │
  └─ MODE=NEW → 创建新 REQ-ID + 目录 + .state.md + .handoff/
               → 检查 reference/ 是否有输入
               → PM 执行完整需求澄清（循环提问，每轮≤3题）
               → 生成 proposal.md（状态 READY）
```

**场景检测逻辑：**
1. 遍历 deliverables/REQ*/.state.md，找 phase ≠ done 的 → RESUME
2. 无未完成的，检查 spec/ 下是否有 .md 文件或有 phase=done 的 REQ → CHANGE
3. 都不满足 → NEW

### 4.3 /ppt-propose 流程

```
propose.sh 前置检查
  → PM 写 handoff → SA 需求分析 → requirement-spec.md
  → PM 写 handoff → SA 架构设计 → design.md
  → PM 写 handoff → TE 测试用例 → testcases.md
  → verify.sh B 级检查
  → 创建基线快照 (baselines/*.v1.md)
  → SR1 人工审批
```

### 4.4 /ppt-apply 流程

```
apply.sh 前置检查 + resume-check.sh 识别已完成页面

FOR 每个待开发页面（跳过已完成）:
    → PM 写 handoff → DE 编码实现 → temp_output/{page}.html
    → PM 写 handoff → TE 审计验证 → temp-test-report.md
    → 失败？→ 新 handoff → DE 修复（最多5轮）
    → 逐页人工检查（轻量确认该页OK，非 SR2）
    → Token 节流：清洗上下文中该页面 HTML 代码，只保留文件路径
END FOR

所有页面开发+审计+人工检查完成后:
    → SR2 正式人工审批（覆盖所有页面）
    → PM 写 handoff → DE 代码合并 → final_output/*.html
    → PM 写 handoff → TE 最终审计 → final-test-report.md
    → SR3 人工审批
```

### 4.5 /ppt-archive 流程

```
archive.sh 前置检查
  → 检测模式：spec/ 下有文件？
      ├─ 无（首次归档）→ 直接复制
      └─ 有（变更归档）→ merge 到现有文件
  → 需求归档：
      首次: cp → spec/requirement-spec.md
      变更: merge 变更内容到 spec/requirement-spec.md
  → 设计归档：
      首次: cp → spec/design.md
      变更: 新增页面追加、修改页面更新、删除页面标记移除
  → 代码归档：
      cp final_output/pages/*.html → output/final/pages/
      cp final_output/shared/ → output/final/shared/
      更新 output/final/index.html（包含所有页面链接）
  → SR4 人工确认结项
```

---

## 五、模板与视觉设计

### 5.1 视觉规范

| 属性 | 值 |
|------|-----|
| 画布尺寸 | 1280×720px (16:9) |
| 底色 | #1e2a3a（深蓝灰） |
| 主文字色 | #ffffff |
| 辅助色 | #c8d6e5（浅蓝灰） |
| 强调色 | #e67e22（橙色） |
| 正文字号 | 18px 起步 |
| 布局规范 | 详见 skills/design-visual.md |

视觉设计的完整规范（色彩、字体、布局、图形元素、图标下载、分步展示等）统一沉淀在 `skills/design-visual.md`，SA 设计和 DE 开发时加载参考。

### 5.2 布局库

| 布局文件 | 适用场景 |
|---------|---------|
| templates/layouts/2-col.html | 两栏对比 |
| templates/layouts/3-col.html | 三栏并列（默认） |
| templates/layouts/4-col.html | 四栏紧凑 |
| templates/layouts/full-width.html | 大图/大表/全幅内容 |
| templates/layouts/left-right.html | 左文右图或左图右文 |
| templates/layouts/chapter-cover.html | 章节封面 |

### 5.3 共享资源

| 文件 | 功能 |
|------|------|
| templates/shared/styles.css | CSS 变量、.slide 容器、字体、颜色、图标类、.step 渐进展示 |
| templates/shared/nav.js | 键盘导航（← → 翻页 + .step 渐进揭示，Esc 返回索引） |
| templates/shared/mermaid-init.js | Mermaid CDN 加载 + 自动渲染 |
| templates/shared/icons/ | Lucide 图标（按需下载 SVG） |
| templates/shared/images/ | 图片资源 |

### 5.4 页面排版规范

DE 拥有完全的布局创意自由，不强制三段式结构。鼓励多样化布局：

- 英雄大图+标题、左右分栏、时间线、数据仪表盘、对比表格
- 引用金句页、流程图解、卡片网格等
- 同一份 PPT 中相邻页面应避免使用相同布局，追求视觉节奏感
- 每页必须有明确标题（h1 或等效），内容信息完整不遗漏
- 每页需有图形元素点缀（图标/图表/插图），避免纯文本页面
- 支持 .step 类实现分步展示（渐进式揭示）

详细规则参见 `skills/design-visual.md`。

---

## 六、脚本设计

| 脚本 | 功能 | 触发时机 |
|------|------|---------|
| init-task.sh | 场景检测（NEW/RESUME/CHANGE）、生成 REQ-ID、创建目录、基线备份、安装依赖 | /ppt-init |
| propose.sh | 检查 proposal.md 存在且 READY | /ppt-propose 前置 |
| apply.sh | 检查 SR1 PASS + design.md 存在 | /ppt-apply 前置 |
| archive.sh | 检查 SR3 PASS + final_output 非空 | /ppt-archive 前置 |
| verify.sh | A/B/C 三级产物校验 | 评审节点 |
| baseline.sh | 基线快照对比 | 变更检测 |
| resume-check.sh | 识别已完成页面 | apply 开始前 |
| playwright-check.sh | Playwright E2E 入口 | TE 审计 |
| check-harness.sh | 框架完整性自检 | 开发/维护时 |

---

## 七、MCP 集成

```json
{
  "mcpServers": {
    "zai-mcp-server": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@z_ai/mcp-server"],
      "env": { "Z_AI_API_KEY": "${Z_AI_API_KEY}", "Z_AI_MODE": "ZHIPU" }
    },
    "web-search-prime": {
      "type": "http",
      "url": "https://open.bigmodel.cn/api/mcp/web_search_prime/mcp",
      "headers": { "Authorization": "Bearer ${Z_AI_API_KEY}" }
    },
    "web-reader": {
      "type": "http",
      "url": "https://open.bigmodel.cn/api/mcp/web_reader/mcp",
      "headers": { "Authorization": "Bearer ${Z_AI_API_KEY}" }
    }
  }
}
```

---

## 八、目录结构

```
ppt-harness/
├── CLAUDE.md              # Claude Code 规则
├── .clinerules            # Cline 规则（同源）
├── .mcp.json              # MCP 配置
├── .gitignore             # Git 忽略规则
├── package.json           # Playwright 依赖
├── agents/                # Agent 角色定义
│   ├── pm.md
│   ├── sa.md
│   ├── de.md
│   └── te.md
├── skills/                # Skill SOP
│   ├── init-clarify.md
│   ├── propose.md
│   ├── dev-test.md
│   ├── post-verify.md
│   ├── spec-merge.md
│   └── design-visual.md   # 视觉设计规范（SA/DE 参考）
├── src/
│   ├── workflow.md        # PM 调度手册
│   ├── core/              # 核心逻辑
│   ├── scripts/           # Shell 脚本
│   └── playwright/        # E2E 测试脚本
├── templates/
│   ├── handoff-template.md
│   ├── state-template.md
│   ├── proposal-template.md
│   ├── requirement-spec-template.md
│   ├── design-template.md
│   ├── testcases-template.md
│   ├── test-report-template.md
│   ├── sr-record-template.md
│   ├── page-skeleton.html
│   ├── index-skeleton.html
│   ├── shared/            # 共享 CSS/JS
│   │   ├── styles.css
│   │   ├── nav.js
│   │   ├── mermaid-init.js
│   │   ├── icons/         # Lucide 图标（按需下载）
│   │   └── images/        # 图片资源
│   └── layouts/           # 布局变体
├── reference/             # 用户输入纲要
├── deliverables/          # 过程产物（按 REQ-ID 分目录）
│   └── REQ001/
│       ├── .state.md
│       ├── .handoff/
│       ├── process.log
│       ├── proposal.md
│       ├── sa/
│       ├── de/
│       ├── te/
│       ├── temp_output/
│       ├── final_output/
│       │   ├── index.html
│       │   ├── shared/
│       │   └── pages/
│       └── baselines/
├── spec/                  # 归档需求与设计
│   ├── requirement-spec.md
│   ├── design.md
│   └── baselines/         # 历史基线备份
│       ├── requirement-spec.v1.md
│       └── design.v1.md
├── output/final/          # 归档最终产物
│   ├── index.html         # 首页/目录
│   ├── shared/            # CSS/JS/图标/图片
│   └── pages/             # 所有章节页面
└── _dev/                  # 私有开发文档（不分发）
    └── doc/
        ├── requirements.md
        └── design.md
```

---

## 九、Token 节流与断点续作

### 9.1 Token 节流机制

- 每完成一个页面的开发+审计后，清洗上下文中该页面的 HTML 代码
- 只保留文件路径引用（如"已完成: deliverables/REQ001/temp_output/chapter-01.html"）
- 下一页开发时重新读取 design.md 对应段落

### 9.2 断点续作机制

- /ppt-init 时自动检测 RESUME 场景（.state.md phase ≠ done），提示用户继续
- apply 开始前执行 resume-check.sh 识别已完成页面
- 跳过已存在于 temp_output/ 或 final_output/ 的页面
- PM 恢复时读取 .state.md 确定恢复点，不依赖对话历史

### 9.3 PM 心跳机制

PM 在关键时机打印心跳信息，格式 `[PM] {描述}`：

| 时机 | 示例 |
|------|------|
| 调度角色前 | `[PM] 调度 SA 执行需求分析` |
| 角色完成后 | `[PM] SA 需求分析完成，产物已验证` |
| 人工审批前 | `[PM] 进入 SR1 人工审批` |
| 审批结果后 | `[PM] SR1 审批通过` |
| 异常处理时 | `[PM] TE 审计失败（轮次 2/5），转发 DE 修复` |
| 流程开始/结束 | `[PM] /ppt-propose 流程启动` |

### 9.4 过程日志

所有角色执行过程记录到 `deliverables/{REQ-ID}/process.log`：

```
[{ISO-8601时间}] [{角色}] {事件描述}
```

写入规则：
- PM 调度前/验证后各一条
- SA/DE/TE 完成任务后一条（含产物路径）
- 人工审批结果一条
- 异常/失败一条（含原因摘要）

日志用途：
- 断点恢复时辅助理解上下文
- 事后审计追溯流程执行情况
- 排查问题时定位失败环节

---

## 十、Playwright E2E 验证

### 10.1 验证流程

```
playwright-check.sh {page_path}
  → 启动 Chromium（headless）
  → 设置视口 1280×720
  → 打开页面（file:// 协议）
  → 执行验证项
  → 截图保存
  → 输出 PASS/FAIL
```

### 10.2 验证项

- .slide 容器存在且尺寸 1280×720
- 三段结构完整（header + keypoint + body）
- 无水平溢出（scrollWidth <= clientWidth）
- 文本内容非空
- 卡片数量与设计一致
- Mermaid 图表渲染（如有）

---

## 变更记录

| 日期 | 变更内容 |
|------|---------|
| 2026-05-14 | 初始版本，汇总系统完整设计 |
| 2026-05-14 | 新增 Handoff 协议设计（第三节 3.3） |
| 2026-05-14 | 新增 PM 心跳与过程日志设计（第九节 9.3/9.4） |
| 2026-05-15 | 修订 4.4 /ppt-apply 流程：逐页人工检查在循环内，SR2 在循环外 |
| 2026-05-15 | 修订 4.2 /ppt-init 流程：三场景检测（NEW/RESUME/CHANGE） |
| 2026-05-15 | 修订 4.5 /ppt-archive 流程：支持首次归档（copy）和变更归档（merge） |
| 2026-05-15 | 修订第八节目录结构：新增 spec/baselines/、output/final/pages/、shared/icons/images/ |
| 2026-05-15 | 修订 5.1 视觉规范：更新为深色调色板，引用 design-visual.md |
| 2026-05-15 | 扩充 3.3 Handoff 协议设计：完整运作流程、命名规范、约束汇总、文件清单 |
