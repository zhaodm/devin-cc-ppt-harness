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

echo "=== /ppt-propose 前置检查 ==="
echo "当前任务: $REQ_ID"
echo ""

if [ ! -f "$DELIVERABLES/proposal.md" ]; then
  echo '{"status":"FAIL","req_id":"'"$REQ_ID"'","message":"proposal.md 不存在"}'
  exit 1
fi

if ! grep -q "READY" "$DELIVERABLES/proposal.md" 2>/dev/null; then
  echo '{"status":"FAIL","req_id":"'"$REQ_ID"'","message":"proposal.md 状态未标记为 READY，请先完成需求澄清流程"}'
  exit 1
fi

# 执行 A 类校验
echo "执行产物校验..."
if bash "$SCRIPT_DIR/verify.sh" "$REQ_ID" A > /dev/null 2>&1; then
  echo "产物校验: PASS"
else
  echo "产物校验: 存在警告（非阻塞）"
fi

echo ""
echo "PASS: 前置条件满足"
echo ""
echo "流程步骤:"
echo "  REQ-1: SA 需求分析"
echo "  REQ-2: SA 架构设计"
echo "  REQ-3: TE 测试用例设计"
echo "  SR1:   PM 需求评审"
echo ""
echo '{"status":"PASS","req_id":"'"$REQ_ID"'","deliverables":"'"$DELIVERABLES"'","next_step":"REQ-1"}'
