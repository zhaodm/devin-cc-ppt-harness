---
skill: init-clarify
trigger: /ppt-init 命令
executor: PM（SA 顾问协助）
---

## 上下文围栏（Context Fence）

执行本 Skill 时，PM MUST 遵守以下约束：

1. **读取角色定义**: 读取 `agents/pm.md`
2. **读取状态文件**: 读取 `deliverables/{REQ-ID}/.state.md` 确认当前阶段
3. **允许读取**: `reference/` 下所有文件、`templates/proposal-template.md`、用户在对话中的直接回复
4. **禁止读取**: 其他角色的产物文件（sa/、de/、te/ 目录）、其他任务的 deliverables
5. **输出隔离**: 仅写入 `deliverables/{REQ-ID}/proposal.md`
6. **状态更新**: 定稿后更新 `deliverables/{REQ-ID}/.state.md`

## 前置条件
- init-task.sh 已执行成功，deliverables/{REQ-ID}/ 目录已创建
- reference/ 下存在至少一个输入文件（md/txt/图片）
- 已确认模式：NEW（全新项目）或 CHANGE（变更迭代）

## 执行步骤

### Step 0: 模式确认（仅变更模式）
如果 init-task.sh 输出 MODE=CHANGE：
1. 读取 spec/requirement-spec.md 和 spec/design.md 作为现有基线
2. 向用户确认变更范围："本次变更涉及哪些内容？（新增页面/修改现有页面/删除页面/内容调整）"
3. 记录变更类型和涉及范围，后续步骤仅围绕变更点展开

### Step 0b: 工作流档位选择

PM 向用户呈现三档选择（仅 CHANGE 模式时触发，NEW 模式默认 full 跳过此步）：

```
[工作流档位选择]
本次变更范围决定流程精简程度：

  fast     — 微调（改文字/图标/样式，1-2个已有页面）
             跳过: propose、TE审计、SR2/SR3
             流程: init → apply(DE开发→人工检查) → archive

  standard — 中等改动（修改多页内容/布局，不新增删除页面）
             跳过: propose
             流程: init → apply(完整循环) → archive

  full     — 大改动（新增页面、结构变更、重设计）
             完整流程: init → propose → apply → archive

请选择档位: fast / standard / full
```

用户选择后：
- 更新 deliverables/{REQ-ID}/.state.md 的 workflow_mode 字段
- fast/standard 模式下，需求澄清简化为：确认改动的页面列表 + 改动描述，直接生成 proposal.md
- full 模式下，继续完整的 Step 1-5 需求澄清

### Step 1: 纲要解读
1. 读取 reference/ 下所有文件，逐个分析内容
2. 如有图片文件（png/jpg/jpeg/gif），调用 zai-vision MCP 识别内容
3. 提取以下信息并记录：
   - 主题关键词
   - 可能的目标受众
   - 已有的核心论点/数据
   - 信息来源线索
4. 如有网页链接，调用 web-reader MCP 抓取内容

### Step 2: 缺失项检测
对照 templates/proposal-template.md 逐项检查，标记状态：

**新建模式：** 全量检测
```
[缺失项检测结果]
- [ ] 演示目标（说服/教学/汇报 + 期望效果）
- [ ] 目标受众（角色 + 知识背景 + 关注点）
- [ ] 章节结构（至少需要章节标题 + 核心论点）
- [ ] 数据与案例来源
- [ ] 视觉要求（信息密度偏好、图表类型）
- [ ] 约束条件（总页数、时长）
```

**变更模式：** 仅检测变更相关项
```
[变更项检测结果]
- [ ] 变更类型（新增/修改/删除）
- [ ] 变更涉及的页面/章节
- [ ] 变更后的内容要点
- [ ] 对现有页面的影响（是否需要调整其他页面）
```

已从纲要中提取到的项标记为 [x]。

### Step 3: 交互澄清（循环）
**规则：每轮最多 3 个问题，优先问最关键的缺失项。**

问题呈现格式：
```
为了完善您的演示文稿方案，需要确认以下信息：

1. {问题1}
2. {问题2}
3. {问题3}
```

收集回答后：
- 更新缺失项检测结果
- 如仍有缺失项，继续下一轮提问
- 如所有必填项已补齐，进入 Step 4

**新建模式必填项判定标准：**
- 演示目标：必须明确是说服/教学/汇报之一
- 目标受众：必须有角色描述
- 章节结构：必须有至少 2 个章节标题
- 每章核心论点：每个章节必须有一句话论点

**变更模式必填项判定标准：**
- 变更类型：必须明确（新增/修改/删除）
- 变更涉及的页面：必须指明具体页面或章节
- 变更后的内容要点：必须有具体描述
- 不重复确认未变更的内容

**可选项（用户不提供则使用默认值）：**
- 信息密度偏好：默认"高"
- 图表类型：默认"按内容自动选择"
- 总页数：默认"不限制"

### Step 4: 草稿生成
1. 基于 templates/proposal-template.md 格式生成完整草稿
2. 填入所有已收集信息
3. 可选项使用默认值或用户指定值
4. **变更模式额外操作：**
   - 在草稿中明确标注"变更类型"和"基线引用"
   - 标注哪些是变更项、哪些沿用基线
   - 列出变更涉及的页面清单
5. 向用户展示完整草稿，格式：

```
[Proposal 草稿 - 请确认]
模式: {NEW/CHANGE}

{完整 proposal 内容}

---
请确认以上内容，或指出需要修改的部分。
```

### Step 5: 定稿确认
- 用户确认"通过/可以/没问题"等肯定回复：
  1. 将 proposal 写入 deliverables/{REQ-ID}/proposal.md
  2. 将状态字段从 DRAFT 改为 READY
  3. 执行自检（见下方）
- 用户要求修改：
  1. 按用户要求修改对应部分
  2. 重新展示草稿
  3. 回到确认环节

## 自检清单
- [ ] deliverables/{REQ-ID}/proposal.md 文件存在
- [ ] 文件非空（> 100 字符）
- [ ] 状态字段为 READY
- [ ] 演示目标已填写
- [ ] 目标受众已填写
- [ ] 章节结构表格至少 2 行
- [ ] 每章核心论点非空

## 输出物
- deliverables/{REQ-ID}/proposal.md（状态 READY）

## 完成标志
自检清单全部通过，向用户报告：
```
[需求澄清完成]
需求编号: {REQ-ID}
模式: {NEW/CHANGE}
工作流档位: {fast/standard/full}
Proposal 状态: READY
基线备份: {spec/baselines/*.vN.md 或 N/A}
下一步: {fast/standard → 输入 /ppt-apply | full → 输入 /ppt-propose}
```
