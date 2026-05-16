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

# 读取 workflow_mode
WF_MODE=$(grep -m1 '^workflow_mode:' "$DELIVERABLES/.state.md" 2>/dev/null \
  | sed 's/workflow_mode: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | tr -d ' ')
WF_MODE="${WF_MODE:-full}"

echo "工作流档位: $WF_MODE"
echo ""

# SR2/SR3/final-test-report 检查（仅 standard 和 full 模式）
if [ "$WF_MODE" != "fast" ]; then
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
fi

# 检查 output/pages 下有文件（所有模式都需要）
HTML_COUNT=$(find "$DELIVERABLES/output/pages" -name '*.html' 2>/dev/null | wc -l | tr -d ' ')
if [ "$HTML_COUNT" -eq 0 ]; then
  echo '{"status":"FAIL","req_id":"'"$REQ_ID"'","message":"output/pages/ 下没有 HTML 文件"}'
  exit 1
fi

# 执行产物校验（standard 和 full 模式）
if [ "$WF_MODE" != "fast" ]; then
  echo "执行产物校验..."
  if bash "$SCRIPT_DIR/verify.sh" "$REQ_ID" B > /dev/null 2>&1; then
    echo "产物校验: PASS"
  else
    echo "产物校验: 存在问题"
    echo "运行 verify.sh $REQ_ID B 查看详情"
  fi
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
