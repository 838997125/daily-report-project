#!/usr/bin/env bash
# common.sh —— daily-report 项目公共函数
# 所有脚本 source 本文件。用 python3 解析 JSON（不依赖 jq）。
set -euo pipefail

# 项目根目录（scripts 的上一级）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIG_FILE="$PROJECT_ROOT/config/config.json"
BACKUP_ROOT="$PROJECT_ROOT/outputs/daily-reports"

log()  { printf '\033[0;36m[INFO]\033[0m  %s\n' "$*"; }
ok()   { printf '\033[0;32m[ OK ]\033[0m  %s\n' "$*"; }
warn() { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*" >&2; }
err()  { printf '\033[0;31m[ERR ]\033[0m  %s\n' "$*" >&2; }

# 用 python3 读 config.json：json_get <dotted.key>
json_get() {
  local key="$1"
  [ -f "$CONFIG_FILE" ] || { err "缺少配置文件 $CONFIG_FILE（先 cp config/config.example.json config/config.json）"; exit 1; }
  python3 - "$CONFIG_FILE" "$key" <<'PY'
import json, sys
path, key = sys.argv[1], sys.argv[2]
cfg = json.load(open(path, encoding='utf-8'))
cur = cfg
for part in key.split('.'):
    if isinstance(cur, dict) and part in cur:
        cur = cur[part]
    else:
        sys.exit(0)
if cur is None:
    sys.exit(0)
print(cur)
PY
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "未找到命令：$1 —— $2"; return 1; }
}

# dws 封装：强制 json
dwsj() { dws "$@" --format json; }

# 取当天日期（Asia/Shanghai）
today() { TZ=Asia/Shanghai date +%F; }
