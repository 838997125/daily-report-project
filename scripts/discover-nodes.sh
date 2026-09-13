#!/usr/bin/env bash
# discover-nodes.sh —— 自动发现知识库里的 日常/日报/周报/项目档案 文件夹 nodeId
# 用法：bash scripts/discover-nodes.sh [搜索根范围]
# 说明：列出知识库根节点，再逐层进入“日常”列出其子文件夹，打印可直接粘进 config.json 的 ID。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

WS="$(json_get workspace_id)"
if [ -z "$WS" ] || [[ "$WS" == *"你的"* ]]; then
  err "请先在 config/config.json 填好 workspace_id（知识库 ID）"
  echo "  知识库 ID 可在钉钉文档知识库 URL 或 dws wiki space list 里找到。"
  dws wiki space list --format json 2>/dev/null | python3 -c "
import json,sys
try:
  d=json.load(sys.stdin)
  items=d.get('spaces') or d.get('items') or (d if isinstance(d,list) else [])
  for it in items:
    print('  -', it.get('name'), '=>', it.get('workspaceId') or it.get('id') or it.get('spaceId'))
except Exception as e:
  print('  （无法自动列出知识库，请手工填写）', file=sys.stderr)
"
  exit 1
fi

list_children() { # $1 folder nodeId
  dws wiki node list --workspace "$WS" --folder "$1" --format json 2>/dev/null
}

echo "知识库根节点："
ROOT_LIST=$(dws wiki node list --workspace "$WS" --format json 2>/dev/null || true)
echo "$ROOT_LIST" | python3 -c "
import json,sys
d=json.load(sys.stdin)
nodes=d.get('nodes') or d.get('items') or (d if isinstance(d,list) else [])
for n in nodes:
  print('  -', n.get('nodeType') or n.get('type'), n.get('name'), '|', n.get('nodeId') or n.get('id'))
"

DAILY_ROOT_ID=$(echo "$ROOT_LIST" | python3 -c "
import json,sys
d=json.load(sys.stdin)
nodes=d.get('nodes') or d.get('items') or (d if isinstance(d,list) else [])
for n in nodes:
  if n.get('name')=='日常':
    print(n.get('nodeId') or n.get('id')); break
" 2>/dev/null || true)

if [ -z "$DAILY_ROOT_ID" ]; then
  warn "知识库根下未直接找到「日常」文件夹。请确认其位置后手工填写以下三个文件夹的 nodeId。"
  exit 0
fi
echo
echo "「日常」nodeId = $DAILY_ROOT_ID"
CHILD=$(list_children "$DAILY_ROOT_ID")
echo "「日常」子节点："
echo "$CHILD" | python3 -c "
import json,sys
d=json.load(sys.stdin)
nodes=d.get('nodes') or d.get('items') or (d if isinstance(d,list) else [])
for n in nodes:
  print('  -', n.get('nodeType') or n.get('type'), n.get('name'), '|', n.get('nodeId') or n.get('id'))
"
echo
echo "可填入 config/config.json："
echo "$CHILD" | python3 -c "
import json,sys
d=json.load(sys.stdin)
nodes=d.get('nodes') or d.get('items') or (d if isinstance(d,list) else [])
m={n.get('name'):(n.get('nodeId') or n.get('id')) for n in nodes}
print('  folder_daily_root      =', m.get('日常') or '(日常自身见上)')
print('  folder_daily          =', m.get('日报'))
print('  folder_weekly         =', m.get('周报'))
print('  folder_project_archive=', m.get('项目档案'))
"
