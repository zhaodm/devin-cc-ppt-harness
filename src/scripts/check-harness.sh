#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== PPT-Harness 框架自检 ==="
echo ""

ERRORS=0

check_exists() {
  local path="$1" label="$2" type="${3:-file}"
  if [ "$type" = "dir" ]; then
    if [ -d "$PROJECT_ROOT/$path" ]; then
      echo "  PASS: $label"
    else
      echo "  FAIL: $label (目录不存在: $path)"
      ERRORS=$((ERRORS + 1))
    fi
  else
    if [ -f "$PROJECT_ROOT/$path" ]; then
      echo "  PASS: $label"
    else
      echo "  FAIL: $label (文件不存在: $path)"
      ERRORS=$((ERRORS + 1))
    fi
  fi
}

check_executable() {
  local path="$1" label="$2"
  if [ -x "$PROJECT_ROOT/$path" ]; then
    echo "  PASS: $label"
  else
    echo "  FAIL: $label (不可执行: $path)"
    ERRORS=$((ERRORS + 1))
  fi
}

# 1. 核心文件
echo "[核心文件]"
check_exists "CLAUDE.md" "CLAUDE.md"
check_exists ".clinerules" ".clinerules"
check_exists ".mcp.json" ".mcp.json"
check_exists "README.md" "README.md"
echo ""

# 2. Agent 角色文件
echo "[Agent 角色文件]"
check_exists "agents/pm.md" "agents/pm.md"
check_exists "agents/sa.md" "agents/sa.md"
check_exists "agents/de.md" "agents/de.md"
check_exists "agents/te.md" "agents/te.md"
echo ""

# 3. Skill 文件
echo "[Skill 文件]"
check_exists "skills/init-clarify.md" "skills/init-clarify.md"
check_exists "skills/propose.md" "skills/propose.md"
check_exists "skills/dev-test.md" "skills/dev-test.md"
check_exists "skills/post-verify.md" "skills/post-verify.md"
check_exists "skills/spec-merge.md" "skills/spec-merge.md"
echo ""

# 4. Workflow
echo "[Workflow]"
check_exists "src/workflow.md" "src/workflow.md"
echo ""

# 5. 脚本文件 + 可执行权限
echo "[脚本文件]"
check_exists "src/scripts/init-task.sh" "src/scripts/init-task.sh"
check_executable "src/scripts/init-task.sh" "init-task.sh 可执行"
check_exists "src/scripts/propose.sh" "src/scripts/propose.sh"
check_executable "src/scripts/propose.sh" "propose.sh 可执行"
check_exists "src/scripts/apply.sh" "src/scripts/apply.sh"
check_executable "src/scripts/apply.sh" "apply.sh 可执行"
check_exists "src/scripts/archive.sh" "src/scripts/archive.sh"
check_executable "src/scripts/archive.sh" "archive.sh 可执行"
check_exists "src/scripts/verify.sh" "src/scripts/verify.sh"
check_executable "src/scripts/verify.sh" "verify.sh 可执行"
check_exists "src/scripts/baseline.sh" "src/scripts/baseline.sh"
check_executable "src/scripts/baseline.sh" "baseline.sh 可执行"
check_exists "src/scripts/playwright-check.sh" "src/scripts/playwright-check.sh"
check_executable "src/scripts/playwright-check.sh" "playwright-check.sh 可执行"
check_exists "src/scripts/resume-check.sh" "src/scripts/resume-check.sh"
check_executable "src/scripts/resume-check.sh" "resume-check.sh 可执行"
echo ""

# 6. 模板文件
echo "[模板文件]"
check_exists "templates/proposal-template.md" "proposal-template.md"
check_exists "templates/requirement-spec-template.md" "requirement-spec-template.md"
check_exists "templates/design-template.md" "design-template.md"
check_exists "templates/testcases-template.md" "testcases-template.md"
check_exists "templates/test-report-template.md" "test-report-template.md"
check_exists "templates/sr-record-template.md" "sr-record-template.md"
check_exists "templates/handoff-template.md" "handoff-template.md"
check_exists "templates/state-template.md" "state-template.md"
check_exists "templates/page-skeleton.html" "page-skeleton.html"
check_exists "templates/index-skeleton.html" "index-skeleton.html"
check_exists "templates/shared/styles.css" "shared/styles.css"
check_exists "templates/shared/nav.js" "shared/nav.js"
check_exists "templates/shared/mermaid-init.js" "shared/mermaid-init.js"
check_exists "templates/layouts/2-col.html" "layouts/2-col.html"
check_exists "templates/layouts/3-col.html" "layouts/3-col.html"
check_exists "templates/layouts/4-col.html" "layouts/4-col.html"
check_exists "templates/layouts/full-width.html" "layouts/full-width.html"
check_exists "templates/layouts/left-right.html" "layouts/left-right.html"
check_exists "templates/layouts/chapter-cover.html" "layouts/chapter-cover.html"
echo ""

# 6b. Playwright
echo "[Playwright]"
check_exists "package.json" "package.json"
check_exists "src/playwright/e2e-check.js" "src/playwright/e2e-check.js"
echo ""

# 7. 目录结构
echo "[目录结构]"
check_exists "agents" "agents/" "dir"
check_exists "skills" "skills/" "dir"
check_exists "src/scripts" "src/scripts/" "dir"
check_exists "src/core" "src/core/" "dir"
check_exists "templates" "templates/" "dir"
check_exists "reference" "reference/" "dir"
check_exists "deliverables" "deliverables/" "dir"
check_exists "spec" "spec/" "dir"
check_exists "output/final" "output/final/" "dir"
echo ""

# 8. CLAUDE.md 完整性（关键段落存在）
echo "[CLAUDE.md 内容校验]"
if grep -q "指令映射" "$PROJECT_ROOT/CLAUDE.md" 2>/dev/null; then
  echo "  PASS: 指令映射段落存在"
else
  echo "  FAIL: 指令映射段落缺失"
  ERRORS=$((ERRORS + 1))
fi
if grep -q "角色隔离" "$PROJECT_ROOT/CLAUDE.md" 2>/dev/null; then
  echo "  PASS: 角色隔离段落存在"
else
  echo "  FAIL: 角色隔离段落缺失"
  ERRORS=$((ERRORS + 1))
fi
if grep -q "产物纪律" "$PROJECT_ROOT/CLAUDE.md" 2>/dev/null; then
  echo "  PASS: 产物纪律段落存在"
else
  echo "  FAIL: 产物纪律段落缺失"
  ERRORS=$((ERRORS + 1))
fi
if grep -q "Handoff 协议" "$PROJECT_ROOT/CLAUDE.md" 2>/dev/null; then
  echo "  PASS: Handoff协议段落存在"
else
  echo "  FAIL: Handoff协议段落缺失"
  ERRORS=$((ERRORS + 1))
fi
echo ""

# 结果
echo "================================"
echo "总检查项: 已完成 | 失败: $ERRORS"
if [ "$ERRORS" -eq 0 ]; then
  echo "结论: PASS - 框架完整"
  exit 0
else
  echo "结论: FAIL - 框架存在 $ERRORS 处问题"
  exit 1
fi
