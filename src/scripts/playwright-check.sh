#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

HTML_PATH="${1:-}"
SCREENSHOT_DIR="${2:-}"

if [ -z "$HTML_PATH" ]; then
  echo "用法: playwright-check.sh <html文件路径> [截图保存目录]"
  echo "示例: playwright-check.sh deliverables/REQ001/temp_output/chapter-01.html deliverables/REQ001/te/screenshots/"
  exit 1
fi

if [[ "$HTML_PATH" != /* ]]; then
  HTML_PATH="$PROJECT_ROOT/$HTML_PATH"
fi

if [ -n "$SCREENSHOT_DIR" ] && [[ "$SCREENSHOT_DIR" != /* ]]; then
  SCREENSHOT_DIR="$PROJECT_ROOT/$SCREENSHOT_DIR"
fi

if [ ! -f "$HTML_PATH" ]; then
  echo "FAIL: 文件不存在: $HTML_PATH"
  exit 1
fi

if [ ! -d "$PROJECT_ROOT/node_modules/playwright" ]; then
  echo "错误: Playwright 未安装"
  echo "请先运行 init-task.sh 或手动执行: cd $PROJECT_ROOT && npm install && npx playwright install chromium"
  exit 1
fi

echo "=== Playwright E2E 验证 ==="
echo "页面: $(basename "$HTML_PATH")"
echo ""

RESULT=$(node "$PROJECT_ROOT/src/playwright/e2e-check.js" "$HTML_PATH" "$SCREENSHOT_DIR" 2>&1) || true

STATUS=$(echo "$RESULT" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
SUMMARY=$(echo "$RESULT" | grep -o '"summary":"[^"]*"' | head -1 | cut -d'"' -f4)
SCREENSHOT=$(echo "$RESULT" | grep -o '"screenshot":"[^"]*"' | head -1 | cut -d'"' -f4)

echo "$RESULT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for c in data.get('checks', []):
        mark = 'PASS' if c['pass'] else 'FAIL'
        detail = ' (' + c.get('detail', '') + ')' if c.get('detail') else ''
        print(f'  {mark}: {c[\"name\"]}{detail}')
    print()
    print(f'截图: {data.get(\"screenshot\", \"无\")}')
    print(f'结论: {data[\"status\"]} ({data.get(\"summary\", \"\")})')
except:
    print(data if isinstance(data, str) else str(data))
" 2>/dev/null || echo "$RESULT"

if [ "$STATUS" = "PASS" ]; then
  exit 0
else
  exit 1
fi
