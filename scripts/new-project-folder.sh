#!/usr/bin/env bash
# new-project-folder.sh —— 在“项目档案”下创建一个项目名目录（四层体系第3层）
# 用法：bash scripts/new-project-folder.sh "<项目名>"
# 创建后会把新 nodeId 追加打印出来，供写进 config.json 的 project_folders 与 SKILL.md 常量。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

NAME="${1:-}"
[ -n "$NAME" ] || { err "用法: bash scripts/new-project-folder.sh \"<项目名>\""; exit 1; }

WS="$(json_get workspace_id)"
PA="$(json_get folder_project_archive)"
if [[ "$WS" == *"你的"* || "$PA" == *"nodeId"* || -z "$PA" ]]; then
  err "请先在 config/config.json 填好 workspace_id 与 folder_project_archive"; exit 1
fi

log "在项目档案下创建目录：$NAME"
OUT=$(dws wiki node create --workspace "$WS" --name "$NAME" --type folder --folder "$PA" --format json)
NID=$(echo "$OUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('nodeId',''))")
[ -n "$NID" ] || { err "创建失败：$OUT"; exit 1; }
ok "已创建：$NAME => $NID"
echo
echo "请把下面这行加进 config/config.json 的 project_folders："
echo "  \"$NAME\": \"$NID\""
echo
echo "接下来在该目录下创建两份文档（用 dws doc create --folder $NID --content-file skill/templates/...）："
echo "  - $NAME｜项目设计文档   （模板 skill/templates/project-design-doc-template.md）"
echo "  - $NAME｜问题与决策档案 （模板 skill/templates/project-archive-template.md）"
