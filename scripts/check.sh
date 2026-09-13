#!/usr/bin/env bash
# check.sh —— 环境自检：依赖、dws 授权、配置、知识库连通性
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

echo "===== daily-report 环境自检 ====="
fail=0

# 依赖
for c in dws node npm python3 bash git; do
  if command -v "$c" >/dev/null 2>&1; then ok "命令 $c"; else err "缺少命令 $c"; fail=1; fi
done

# 配置
if [ -f "$CONFIG_FILE" ]; then
  ok "配置文件存在 config/config.json"
else
  warn "无 config/config.json（cp config/config.example.json config/config.json 后填写）"
  fail=1
fi

# dws 授权
st=$(dws auth status --format json 2>/dev/null || echo '{}')
if echo "$st" | grep -q '"authenticated": *true'; then
  uname=$(echo "$st" | python3 -c "import json,sys; print(json.load(sys.stdin).get('user_name','?'))" 2>/dev/null || echo '?')
  ok "dws 已授权：$uname"
else
  err "dws 未授权 → 运行 dws auth login（远程用 --device）"
  fail=1
fi

# 知识库/文件夹连通性
if [ -f "$CONFIG_FILE" ]; then
  WS=$(json_get workspace_id)
  FD=$(json_get folder_daily)
  PA=$(json_get folder_project_archive)
  if [ -n "$WS" ] && [[ "$WS" != *"你的"* ]]; then
    if dws wiki node list --workspace "$WS" --folder "$FD" --format json >/dev/null 2>&1; then
      ok "日报文件夹可访问：$FD"
    else
      warn "日报文件夹访问失败，检查 folder_daily=$FD"
    fi
    if dws wiki node list --workspace "$WS" --folder "$PA" --format json >/dev/null 2>&1; then
      ok "项目档案文件夹可访问：$PA"
    else
      warn "项目档案文件夹访问失败，检查 folder_project_archive=$PA"
    fi
  else
    warn "config 里 workspace_id 还是占位值，跳过知识库连通性检查"
  fi
fi

echo "================================"
if [ "$fail" = "0" ]; then ok "自检通过（警告项不阻断，请按提示完善配置）"; exit 0
else err "自检发现必须修复的问题"; exit 1; fi
