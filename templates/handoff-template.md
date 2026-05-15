---
handoff_id: "{REQ-ID}-{TASK-SLUG}"
from: PM
to: "{SA|DE|TE}"
task_type: "{需求分析|架构设计|编码实现|审计验证|代码合并|测试用例设计}"
created_at: "{YYYY-MM-DDTHH:MM:SSZ}"
---

## 任务描述

{一段话描述本次任务的目标和范围}

## 允许读取的文件（白名单）

仅以下文件可被读取，禁止读取白名单外的任何文件：

- `agents/{role}.md`
- {file_path_1}
- {file_path_2}

## 期望输出

- 输出路径: `{output_path}`
- 格式要求: {模板引用或格式描述}

## 约束条件

- {constraint_1}
- {constraint_2}

## 参考 Skill

- `skills/{skill-file}.md` 中的 {Step N}

## 轮次信息

- 当前轮次: {N}/5
- 上轮失败原因: {摘要或 N/A}
- 失败报告路径: {path 或 N/A}
