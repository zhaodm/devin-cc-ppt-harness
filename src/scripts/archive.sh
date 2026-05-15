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

echo "=== /ppt-archive 前置检查 ==="
echo "当前任务: $REQ_ID"
echo ""

if [ ! -f "$DELIVERABLES/SR2-record.md" ]; then
  echo '{"status":"FAIL","req_id":"'"$REQ_ID"'","message":"SR2-record.md 不存在，请先完成 SR2 人工审批"}'
  exit 1
fi

if ! grep -q "PASS" "$DELIVERABLES/SR2-record.md" 2>/dev/null; then
  echo '{"status":"FAIL","req_id":"'"$REQ_ID"'","message":"SR2-record.md 未标记 PASS"}'
  exit 1
fi

if [ ! -f "$DELIVERABLES/SR3-record.md" ]; then
  echo '{"status":"FAIL","req_id":"'"$REQ_ID"'","message":"SR3-record.md 不存在，请先完成 /ppt-apply 流程"}'
  exit 1
fi

if ! grep -q "PASS" "$DELIVERABLES/SR3-record.md" 2>/dev/null; then
  echo '{"status":"FAIL","req_id":"'"$REQ_ID"'","message":"SR3-record.md 未标记 PASS"}'
  exit 1
fi

if [ ! -f "$DELIVERABLES/te/final-test-report.md" ]; then
  echo '{"status":"FAIL","req_id":"'"$REQ_ID"'","message":"final-test-report.md 不存在"}'
  exit 1
fi

if ! grep -q "PASS" "$DELIVERABLES/te/final-test-report.md" 2>/dev/null; then
  echo '{"status":"FAIL","req_id":"'"$REQ_ID"'","message":"最终审计报告未标记为 PASS"}'
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
echo "  ARC-1: 需求归档"
echo "  ARC-2: 设计归档"
echo "  ARC-3: 代码归档"
echo "  SR4:   项目结项确认（人工）"
echo ""
echo '{"status":"PASS","req_id":"'"$REQ_ID"'","deliverables":"'"$DELIVERABLES"'","next_step":"ARC-1"}'
