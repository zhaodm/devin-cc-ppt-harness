执行 /ppt-propose 流程。

1. 执行 `bash src/scripts/propose.sh` 检查前置条件，如果 FAIL 则报告原因并终止
2. 按 src/workflow.md 中 /ppt-propose 流程和 skills/propose.md 执行
3. 严格遵守 Handoff 协议：每次调度角色前写入 handoff 文件、更新 .state.md、打印心跳、写日志
