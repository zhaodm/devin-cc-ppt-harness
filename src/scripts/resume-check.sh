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
  echo '{"status":"FAIL","message":"没有找到任何任务目录"}'
  exit 1
fi

DELIVERABLES="$DELIVERABLES_ROOT/$REQ_ID"
DESIGN="$DELIVERABLES/sa/design.md"

echo "=== 断点续作检测: $REQ_ID ==="
echo ""

if [ ! -f "$DESIGN" ]; then
  echo "SKIP: design.md 不存在（尚未进入开发阶段）"
  exit 0
fi

# 从 design.md 提取所有页面文件名
ALL_PAGES=$(grep -oE 'chapter-[0-9]+\.html|P[0-9]+\.html|page-[0-9]+\.html' "$DESIGN" 2>/dev/null | sort -u)

if [ -z "$ALL_PAGES" ]; then
  # 尝试从页面设计段落提取
  ALL_PAGES=$(grep -oE '[a-zA-Z0-9_-]+\.html' "$DESIGN" 2>/dev/null | grep -v 'index\|skeleton\|template' | sort -u)
fi

if [ -z "$ALL_PAGES" ]; then
  echo "WARN: 无法从 design.md 中提取页面列表"
  echo "请确保 design.md 中包含页面文件名"
  exit 0
fi

TOTAL=0
DONE=0
TODO=""

for page in $ALL_PAGES; do
  TOTAL=$((TOTAL + 1))
  if [ -f "$DELIVERABLES/final_output/$page" ]; then
    echo "  DONE (final): $page"
    DONE=$((DONE + 1))
  elif [ -f "$DELIVERABLES/temp_output/$page" ]; then
    echo "  DONE (temp):  $page"
    DONE=$((DONE + 1))
  else
    echo "  TODO:         $page"
    TODO="${TODO}${page}\n"
  fi
done

echo ""
echo "================================"
echo "总页面: $TOTAL | 已完成: $DONE | 待开发: $((TOTAL - DONE))"

if [ "$DONE" -eq "$TOTAL" ]; then
  echo "状态: 所有页面已完成"
else
  echo "状态: 从以下页面继续开发"
  printf "%b" "$TODO" | head -1 | xargs -I{} echo "下一页: {}"
fi

echo ""
# 输出结构化 JSON
NEXT_PAGE=$(printf "%b" "$TODO" | head -1 | tr -d '\n')
echo "{\"req_id\":\"$REQ_ID\",\"total\":$TOTAL,\"done\":$DONE,\"remaining\":$((TOTAL - DONE)),\"next_page\":\"$NEXT_PAGE\"}"
