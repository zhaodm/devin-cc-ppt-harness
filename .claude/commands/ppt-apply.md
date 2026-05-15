执行 /ppt-apply 流程。

1. 执行 `bash src/scripts/apply.sh` 检查前置条件，如果 FAIL 则报告原因并终止
2. 执行 `bash src/scripts/resume-check.sh` 识别已完成页面
3. 按 src/workflow.md 中 /ppt-apply 流程执行，使用 skills/dev-test.md + skills/post-verify.md
4. 严格遵守 Handoff 协议：每次调度角色前写入 handoff 文件、更新 .state.md、打印心跳、写日志
5. 每完成一个页面后清洗上下文中的 HTML 代码，只保留文件路径引用
