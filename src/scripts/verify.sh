#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DELIVERABLES_ROOT="$PROJECT_ROOT/deliverables"

REQ_ID="${1:-}"
CHECK_LEVEL="${2:-A}"

if [ -z "$REQ_ID" ]; then
  REQ_ID=$(find "$DELIVERABLES_ROOT" -maxdepth 1 -type d -name 'REQ*' 2>/dev/null \
    | sort | tail -1 | xargs basename 2>/dev/null || echo "")
fi

if [ -z "$REQ_ID" ]; then
  echo '{"status":"FAIL","message":"没有找到任何任务目录"}'
  exit 1
fi

DELIVERABLES="$DELIVERABLES_ROOT/$REQ_ID"
ERRORS=0
CHECKS=0
RESULTS=""

add_result() {
  local check="$1" result="$2" detail="${3:-}"
  CHECKS=$((CHECKS + 1))
  if [ "$result" = "FAIL" ]; then
    ERRORS=$((ERRORS + 1))
  fi
  RESULTS="${RESULTS}  ${result}: ${check}"
  if [ -n "$detail" ]; then
    RESULTS="${RESULTS} (${detail})"
  fi
  RESULTS="${RESULTS}\n"
}

# === A类检查：文件存在性 + 非空 ===
check_file_exists() {
  local filepath="$1" label="$2"
  if [ ! -f "$filepath" ]; then
    add_result "$label" "FAIL" "文件不存在"
  elif [ ! -s "$filepath" ]; then
    add_result "$label" "FAIL" "文件为空"
  else
    add_result "$label" "PASS"
  fi
}

run_check_a() {
  echo "=== A类检查：文件存在性 + 非空 ==="
  check_file_exists "$DELIVERABLES/proposal.md" "proposal.md"

  if [ -d "$DELIVERABLES/sa" ]; then
    check_file_exists "$DELIVERABLES/sa/requirement-spec.md" "sa/requirement-spec.md"
    check_file_exists "$DELIVERABLES/sa/design.md" "sa/design.md"
  fi

  if [ -d "$DELIVERABLES/te" ]; then
    check_file_exists "$DELIVERABLES/te/testcases.md" "te/testcases.md"
  fi

  if [ -d "$DELIVERABLES/output/pages" ]; then
    local html_count
    html_count=$(find "$DELIVERABLES/output/pages" -name '*.html' | wc -l | tr -d ' ')
    if [ "$html_count" -gt 0 ]; then
      for f in "$DELIVERABLES/output/pages"/*.html; do
        check_file_exists "$f" "output/pages/$(basename "$f")"
      done
    fi
  fi
}

# === B类检查：格式合规 ===
run_check_b() {
  echo "=== B类检查：格式合规 ==="

  # proposal 状态检查
  if [ -f "$DELIVERABLES/proposal.md" ]; then
    if grep -q "状态:.*READY\|状态: READY" "$DELIVERABLES/proposal.md" 2>/dev/null; then
      add_result "proposal.md 状态为 READY" "PASS"
    else
      add_result "proposal.md 状态为 READY" "FAIL" "状态非 READY"
    fi
  fi

  # requirement-spec SHALL 格式
  if [ -f "$DELIVERABLES/sa/requirement-spec.md" ]; then
    if grep -q "SHALL" "$DELIVERABLES/sa/requirement-spec.md" 2>/dev/null; then
      add_result "requirement-spec 含 SHALL 格式" "PASS"
    else
      add_result "requirement-spec 含 SHALL 格式" "FAIL" "未找到 SHALL 关键字"
    fi
  fi

  # design 页面清单
  if [ -f "$DELIVERABLES/sa/design.md" ]; then
    if grep -q "P0[0-9]" "$DELIVERABLES/sa/design.md" 2>/dev/null; then
      add_result "design.md 含页面编号" "PASS"
    else
      add_result "design.md 含页面编号" "FAIL" "未找到页面编号 P0x"
    fi
  fi

  # SR record PASS 标记
  for sr in SR1-record.md SR2-record.md SR3-record.md; do
    if [ -f "$DELIVERABLES/$sr" ]; then
      if grep -q "PASS" "$DELIVERABLES/$sr" 2>/dev/null; then
        add_result "$sr 标记 PASS" "PASS"
      else
        add_result "$sr 标记 PASS" "FAIL" "未找到 PASS 标记"
      fi
    fi
  done
}

# === C类检查：HTML 结构完整性 ===
run_check_c() {
  echo "=== C类检查：HTML 结构完整性 ==="

  local html_files=""
  if [ -d "$DELIVERABLES/output/pages" ]; then
    html_files=$(find "$DELIVERABLES/output/pages" -name '*.html' 2>/dev/null)
  fi

  for f in $html_files; do
    local fname
    fname=$(basename "$f")

    # 16:9 容器
    if grep -q "slide" "$f" 2>/dev/null; then
      add_result "$fname: .slide 容器" "PASS"
    else
      add_result "$fname: .slide 容器" "FAIL" "未找到 .slide 类"
    fi

    # 三段结构
    if grep -q "slide-header" "$f" 2>/dev/null; then
      add_result "$fname: slide-header" "PASS"
    else
      add_result "$fname: slide-header" "FAIL" "缺少 slide-header"
    fi

    if grep -q "slide-keypoint" "$f" 2>/dev/null; then
      add_result "$fname: slide-keypoint" "PASS"
    else
      add_result "$fname: slide-keypoint" "FAIL" "缺少 slide-keypoint"
    fi

    if grep -q "slide-body" "$f" 2>/dev/null; then
      add_result "$fname: slide-body" "PASS"
    else
      add_result "$fname: slide-body" "FAIL" "缺少 slide-body"
    fi

    # DOCTYPE
    if grep -q "<!DOCTYPE html>" "$f" 2>/dev/null; then
      add_result "$fname: DOCTYPE" "PASS"
    else
      add_result "$fname: DOCTYPE" "FAIL" "缺少 DOCTYPE 声明"
    fi
  done

  if [ -z "$html_files" ]; then
    add_result "HTML 文件" "FAIL" "未找到任何 HTML 文件"
  fi
}

# 执行检查
case "$CHECK_LEVEL" in
  A) run_check_a ;;
  B) run_check_a; run_check_b ;;
  C) run_check_a; run_check_b; run_check_c ;;
  *) echo "用法: verify.sh [REQ-ID] [A|B|C]"; exit 1 ;;
esac

# 输出结果
echo ""
printf "%b" "$RESULTS"
echo ""
echo "================================"
echo "检查级别: $CHECK_LEVEL | 总检查项: $CHECKS | 通过: $((CHECKS - ERRORS)) | 失败: $ERRORS"

if [ "$ERRORS" -eq 0 ]; then
  echo "结论: PASS"
  exit 0
else
  echo "结论: FAIL"
  exit 1
fi
