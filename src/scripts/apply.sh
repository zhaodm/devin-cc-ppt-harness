#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DELIVERABLES_ROOT="$PROJECT_ROOT/deliverables"

REQ_ID=$(find "$DELIVERABLES_ROOT" -maxdepth 1 -type d -name 'REQ*' 2>/dev/null \
  | sort | tail -1 | xargs basename 2>/dev/null || echo "")

if [ -z "$REQ_ID" ]; then
  echo '{"status":"FAIL","req_id":"","message":"没有找到任何任务目录，请先执行 /ppt-init"}'
  exit 1
fi

DELIVERABLES="$DELIVERABLES_ROOT/$REQ_ID"

echo "=== /ppt-apply 前置检查 ==="
echo "当前任务: $REQ_ID"
echo ""

if [ ! -f "$DELIVERABLES/SR1-record.md" ]; then
  echo '{"status":"FAIL","req_id":"'"$REQ_ID"'","message":"SR1-record.md 不存在，请先完成 /ppt-propose 流程"}'
  exit 1
fi

if [ ! -f "$DELIVERABLES/sa/design.md" ]; then
  echo '{"status":"FAIL","req_id":"'"$REQ_ID"'","message":"design.md 不存在"}'
  exit 1
fi

if [ ! -f "$DELIVERABLES/te/testcases.md" ]; then
  echo '{"status":"FAIL","req_id":"'"$REQ_ID"'","message":"testcases.md 不存在"}'
  exit 1
fi

# 执行 B 类校验
echo "执行产物校验..."
if bash "$SCRIPT_DIR/verify.sh" "$REQ_ID" B > /dev/null 2>&1; then
  echo "产物校验: PASS"
else
  echo "产物校验: 存在问题"
  echo "运行 verify.sh $REQ_ID B 查看详情"
fi

echo ""
echo "PASS: 前置条件满足"
echo ""
echo "流程步骤:"
echo "  DEV-1:  DE 编码实现"
echo "  TEST-1: TE 审计验证"
echo "  SR2:    PM 功能评审（人工）"
echo "  DEV-2:  DE 代码合并"
echo "  TEST-2: TE 审计验证"
echo "  SR3:    PM 功能评审（人工）"
echo ""
echo '{"status":"PASS","req_id":"'"$REQ_ID"'","deliverables":"'"$DELIVERABLES"'","next_step":"DEV-1"}'
