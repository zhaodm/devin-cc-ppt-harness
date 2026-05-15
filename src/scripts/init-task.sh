#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DELIVERABLES_ROOT="$PROJECT_ROOT/deliverables"
SPEC_DIR="$PROJECT_ROOT/spec"

# 首次运行：安装 npm 依赖和 Playwright Chromium
if [ ! -d "$PROJECT_ROOT/node_modules/playwright" ]; then
  echo "首次运行，安装依赖..."
  (cd "$PROJECT_ROOT" && npm install --silent 2>/dev/null)
  echo "安装 Playwright Chromium..."
  (cd "$PROJECT_ROOT" && npx playwright install chromium 2>/dev/null)
  echo "依赖安装完成"
  echo ""
fi

# ============================================================
# 场景检测：NEW / RESUME / CHANGE
# ============================================================

MODE="NEW"
RESUME_REQ=""

# 检测未完成的 REQ（.state.md 中 phase 不是 done/archived）
for STATE_FILE in "$DELIVERABLES_ROOT"/REQ*/.state.md; do
  [ -f "$STATE_FILE" ] || continue
  # 检查 phase 字段是否为 done 或 archived
  PHASE=$(grep -m1 '^phase:' "$STATE_FILE" | sed 's/phase: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | tr -d ' ')
  if [ "$PHASE" != "done" ] && [ "$PHASE" != "archived" ]; then
    RESUME_REQ=$(basename "$(dirname "$STATE_FILE")")
    MODE="RESUME"
    break
  fi
done

# 如果没有未完成的，检测是否有已完成的（变更模式）
if [ "$MODE" = "NEW" ]; then
  SPEC_FILES=$(find "$SPEC_DIR" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  DONE_COUNT=$(grep -rl '^phase:.*\(done\|archived\)' "$DELIVERABLES_ROOT"/REQ*/.state.md 2>/dev/null | wc -l | tr -d ' ')
  if [ "$SPEC_FILES" -gt 0 ] || [ "$DONE_COUNT" -gt 0 ]; then
    MODE="CHANGE"
  fi
fi

# ============================================================
# 输出检测结果
# ============================================================

echo "================================"
echo "场景检测"
echo "================================"
echo "MODE: $MODE"

if [ "$MODE" = "RESUME" ]; then
  echo ""
  echo "检测到未完成的需求: $RESUME_REQ"
  echo "状态文件: $DELIVERABLES_ROOT/$RESUME_REQ/.state.md"
  echo ""
  echo "建议: 继续执行该需求对应的阶段命令（/ppt-propose 或 /ppt-apply）"
  echo "如需放弃并开始新需求，请先手动将 .state.md 的 phase 改为 done 或 archived"
  exit 0
fi

# ============================================================
# CHANGE 模式：备份当前基线
# ============================================================

if [ "$MODE" = "CHANGE" ]; then
  echo ""
  echo "检测到已完成的历史需求，进入变更模式"

  # 计算基线版本号
  BASELINE_DIR="$PROJECT_ROOT/spec/baselines"
  mkdir -p "$BASELINE_DIR"
  LAST_VER=$(find "$BASELINE_DIR" -name '*.v*.md' 2>/dev/null \
    | sed 's/.*\.v\([0-9]*\)\.md/\1/' | sort -n | tail -1)
  if [ -z "$LAST_VER" ]; then
    NEXT_VER=1
  else
    NEXT_VER=$((LAST_VER + 1))
  fi

  # 备份当前 spec/ 到 spec/baselines/
  for SPEC_FILE in "$SPEC_DIR"/*.md; do
    [ -f "$SPEC_FILE" ] || continue
    BASENAME=$(basename "$SPEC_FILE" .md)
    cp "$SPEC_FILE" "$BASELINE_DIR/${BASENAME}.v${NEXT_VER}.md"
    echo "  基线备份: spec/baselines/${BASENAME}.v${NEXT_VER}.md"
  done
  echo ""
fi

# ============================================================
# 创建新 REQ 目录（NEW 和 CHANGE 共用）
# ============================================================

LAST_NUM=$(find "$DELIVERABLES_ROOT" -maxdepth 1 -type d -name 'REQ*' 2>/dev/null \
  | sed 's/.*REQ//' | sort -n | tail -1)

if [ -z "$LAST_NUM" ]; then
  NEXT_NUM=1
else
  NEXT_NUM=$((LAST_NUM + 1))
fi

REQ_ID=$(printf "REQ%03d" "$NEXT_NUM")
DELIVERABLES="$DELIVERABLES_ROOT/$REQ_ID"

mkdir -p "$DELIVERABLES/sa"
mkdir -p "$DELIVERABLES/de"
mkdir -p "$DELIVERABLES/te"
mkdir -p "$DELIVERABLES/output/pages"
mkdir -p "$DELIVERABLES/output/shared"
mkdir -p "$DELIVERABLES/baselines"
mkdir -p "$DELIVERABLES/.handoff"

cp "$PROJECT_ROOT/templates/state-template.md" "$DELIVERABLES/.state.md"
sed -i '' "s/{REQ-ID}/$REQ_ID/g" "$DELIVERABLES/.state.md" 2>/dev/null || \
sed -i "s/{REQ-ID}/$REQ_ID/g" "$DELIVERABLES/.state.md"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
sed -i '' "s/{YYYY-MM-DDTHH:MM:SSZ}/$NOW/g" "$DELIVERABLES/.state.md" 2>/dev/null || \
sed -i "s/{YYYY-MM-DDTHH:MM:SSZ}/$NOW/g" "$DELIVERABLES/.state.md"

cp "$PROJECT_ROOT/templates/proposal-template.md" "$DELIVERABLES/proposal.md"

sed -i '' "s/{REQ-ID}/$REQ_ID/g" "$DELIVERABLES/proposal.md" 2>/dev/null || \
sed -i "s/{REQ-ID}/$REQ_ID/g" "$DELIVERABLES/proposal.md"

TODAY=$(date +%Y-%m-%d)
sed -i '' "s/{date}/$TODAY/g" "$DELIVERABLES/proposal.md" 2>/dev/null || \
sed -i "s/{date}/$TODAY/g" "$DELIVERABLES/proposal.md"

REF_COUNT=$(find "$PROJECT_ROOT/reference" -type f ! -name '.gitkeep' | wc -l | tr -d ' ')

echo "================================"
echo "任务初始化完成"
echo "================================"
echo "需求编号: $REQ_ID"
echo "模式: $MODE"
echo "产物目录: $DELIVERABLES"
echo "参考文件: ${REF_COUNT} 个"
echo ""
echo "目录结构:"
echo "  $REQ_ID/"
echo "  ├── proposal.md (已从模板创建)"
echo "  ├── .state.md  (流程状态追踪)"
echo "  ├── .handoff/  (Handoff 协议文件)"
echo "  ├── sa/"
echo "  ├── de/"
echo "  ├── te/"
echo "  ├── output/"
echo "  │   ├── pages/"
echo "  │   └── shared/"
echo "  └── baselines/"
echo ""
if [ "$MODE" = "CHANGE" ]; then
  echo "变更模式: 基线已备份，需求澄清将聚焦变更点"
  echo "基线引用: spec/baselines/*.v${NEXT_VER}.md"
  echo ""
fi
if [ "$REF_COUNT" -eq 0 ]; then
  echo "提示: reference/ 目录为空，请先放入纲要文件"
else
  echo "下一步: 启动需求澄清流程"
fi
