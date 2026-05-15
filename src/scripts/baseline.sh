#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DELIVERABLES_ROOT="$PROJECT_ROOT/deliverables"

REQ_ID="${1:-}"

if [ -z "$REQ_ID" ]; then
  REQ_ID=$(find "$DELIVERABLES_ROOT" -maxdepth 1 -type d -name 'REQ*' 2>/dev/null \
    | sort | tail -1 | xargs basename 2>/dev/null || echo "")
fi

if [ -z "$REQ_ID" ]; then
  echo "FAIL: 没有找到任何任务目录"
  exit 1
fi

DELIVERABLES="$DELIVERABLES_ROOT/$REQ_ID"
BASELINES="$DELIVERABLES/baselines"

echo "=== 基线对比: $REQ_ID ==="
echo ""

if [ ! -d "$BASELINES" ]; then
  echo "SKIP: baselines/ 目录不存在（尚未创建基线）"
  exit 0
fi

BASELINE_COUNT=$(find "$BASELINES" -type f -name '*.md' | wc -l | tr -d ' ')
if [ "$BASELINE_COUNT" -eq 0 ]; then
  echo "SKIP: baselines/ 目录为空（尚未创建基线）"
  exit 0
fi

ERRORS=0

compare_file() {
  local baseline="$1" current="$2" label="$3"

  if [ ! -f "$current" ]; then
    echo "  WARN: $label - 当前文件不存在（可能已被删除）"
    return
  fi

  if diff -q "$baseline" "$current" > /dev/null 2>&1; then
    echo "  PASS: $label - 与基线一致"
  else
    echo "  DIFF: $label - 与基线存在差异"
    echo "    基线: $baseline"
    echo "    当前: $current"
    echo "    差异摘要:"
    diff --brief "$baseline" "$current" 2>/dev/null || true
    ERRORS=$((ERRORS + 1))
  fi
}

# 对比 requirement-spec
for f in "$BASELINES"/requirement-spec.v*.md; do
  if [ -f "$f" ]; then
    LATEST_REQ_BASELINE="$f"
  fi
done
if [ -n "${LATEST_REQ_BASELINE:-}" ] && [ -f "$DELIVERABLES/sa/requirement-spec.md" ]; then
  compare_file "$LATEST_REQ_BASELINE" "$DELIVERABLES/sa/requirement-spec.md" "requirement-spec.md"
fi

# 对比 design
for f in "$BASELINES"/design.v*.md; do
  if [ -f "$f" ]; then
    LATEST_DESIGN_BASELINE="$f"
  fi
done
if [ -n "${LATEST_DESIGN_BASELINE:-}" ] && [ -f "$DELIVERABLES/sa/design.md" ]; then
  compare_file "$LATEST_DESIGN_BASELINE" "$DELIVERABLES/sa/design.md" "design.md"
fi

# 对比 testcases
for f in "$BASELINES"/testcases.v*.md; do
  if [ -f "$f" ]; then
    LATEST_TC_BASELINE="$f"
  fi
done
if [ -n "${LATEST_TC_BASELINE:-}" ] && [ -f "$DELIVERABLES/te/testcases.md" ]; then
  compare_file "$LATEST_TC_BASELINE" "$DELIVERABLES/te/testcases.md" "testcases.md"
fi

echo ""
echo "================================"
if [ "$ERRORS" -eq 0 ]; then
  echo "结论: PASS - 所有文件与基线一致（或无基线可比）"
  exit 0
else
  echo "结论: WARN - 发现 $ERRORS 处与基线不一致"
  echo "如果这些变更是经过评审批准的，可以忽略此警告"
  exit 0
fi
