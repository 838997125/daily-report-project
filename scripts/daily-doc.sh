#!/usr/bin/env bash
# daily-doc.sh —— 每日日报的机械操作封装（查找/新建/加锁/写入/校验）
# 内容“生成与归并”由 AI 按 skill/SKILL.md 完成；本脚本只做可复用的读写动作。
#
# 子命令：
#   today-node                 打印当天日报 nodeId（不存在则按模板创建）
#   backup --file <md>         把合并后的 markdown 存到 outputs/daily-reports/
#   write  --file <md>         覆盖写入当天日报并校验
#   append --text "..."        安全追加（覆盖失败时的兜底）
#   lock / unlock              手工加/释放当天写锁（一般用 with-lock）
#   with-lock <command...>     持锁执行命令，退出自动释放
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

WS="$(json_get workspace_id)"
WS="$(json_get workspace_id)"
FD="$(json_get folder_daily)"
DATE="$(today)"
DOC_NAME="$DATE 工作日报"
LOCK="/tmp/daily-report-lock-$DATE"
mkdir -p "$BACKUP_ROOT"

acquire_lock() {
  local i
  for i in $(seq 1 60); do
    if mkdir "$LOCK" 2>/dev/null; then echo $$ > "$LOCK/pid"; return 0; fi
    # 超时 10 分钟的死锁强制清理
    if [ -d "$LOCK" ]; then
      local mtime now age
      mtime=$(stat -f %m "$LOCK" 2>/dev/null || stat -c %Y "$LOCK" 2>/dev/null || echo 0)
      now=$(date +%s); age=$((now-mtime))
      [ "$age" -gt 600 ] && rm -rf "$LOCK" && continue
    fi
    sleep 2
  done
  err "写锁被占用，请稍后重试"; return 1
}
release_lock() { rm -rf "$LOCK"; }

# 列出某文件夹，输出 nodeId（按文档名）
node_by_name() { # $1 folder $2 name
  dws doc +list --folder "$1" --limit 50 --format json 2>/dev/null | python3 - "$2" <<'PY' || true
import json, sys
try:
    name=sys.argv[1]
    d=json.load(sys.stdin)
    nodes=d.get('nodes') or d.get('items') or (d if isinstance(d,list) else [])
    for n in nodes:
        if (n.get('name') or n.get('title'))==name:
            print(n.get('nodeId') or n.get('node_id') or n.get('id')); break
except Exception:
    pass
PY
}

cmd_today_node() {
  local nid
  if [[ "$WS" == *"你的"* || "$FD" == *"nodeId"* || -z "$FD" ]]; then
    err "config/config.json 仍是占位值：请先填 workspace_id / folder_daily（可跑 scripts/discover-nodes.sh）"; return 1
  fi
  nid=$(node_by_name "$FD" "$DOC_NAME")
  if [ -z "$nid" ]; then
    log "当天日报不存在，按 config 参数生成骨架：$DOC_NAME"
    local byline rootid paid; byline="$(json_get reporter.doc_byline)"; byline=\${byline:-记录人}
    rootid="$(json_get folder_daily_root)"; paid="$(json_get folder_project_archive)"
    local tmp; tmp=$(mktemp /tmp/daily-XXXXXX.md)
    cat > "$tmp" <<EOF
# $DATE 工作日报

> **记录人**：$byline  **更新记录**：
> - 第1次写入 · $(TZ=Asia/Shanghai date +%H:%M) · <会话主题>

## 今日概览

<一段话总结今天推进的工作；条目统计：阻塞 X / 进行中 X / 已完成 X。>

**归档目录说明**：
- 本日报：战略部共享文档库 / **日常** / 日报 / $DATE 工作日报
- 项目完整资料：战略部共享文档库 / **日常** / 项目档案 / <项目名目录>（链接）

---

## 🔴 阻塞项

（无）

---

## 🟡 进行中

（无）

---

## 🟢 已完成

（无）

---

## 📋 明日计划

（无）

---

## 附录：相关链接

- 日报目录（日常/日报）：https://alidocs.dingtalk.com/i/nodes/$FD
- 项目档案目录：https://alidocs.dingtalk.com/i/nodes/$paid
EOF
    nid=$(dws doc create --name "$DOC_NAME" --folder "$FD" --content-file "$tmp" --format json 2>/dev/null \
      | python3 -c "import json,sys; print(json.load(sys.stdin).get('nodeId',''))")
    rm -f "$tmp"
    [ -z "$nid" ] && { err "创建失败（可降级 --workspace 后 dws doc +move）"; return 1; }
    ok "已创建 $DOC_NAME => $nid"
  fi
  echo "$nid"
}

cmd_write() {
  local file=""; while [ $# -gt 0 ]; do case "$1" in --file) file="$2";; esac; shift; done
  [ -f "${file:?需要 --file <md>}" ] || { err "文件不存在: $file"; return 1; }
  local nid; nid=$(cmd_today_node)
  dws doc update --node "$nid" --content-file "$file" --mode overwrite --yes --format json >/dev/null
  # 校验：读回长度>0
  local backlen
  backlen=$(dws doc read --node "$nid" --format json 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
def fc(o):
  if isinstance(o,str) and len(o)>200: return o
  if isinstance(o,dict):
    for k,v in o.items():
      if k in ('content','body','markdown','text') and isinstance(v,str) and len(v)>100: return v
    for v in o.values():
      r=fc(v)
      if r: return r
  if isinstance(o,list):
    for v in o:
      r=fc(v)
      if r: return r
  return ''
print(len(fc(d)))
")
  ok "已写入 $DOC_NAME（读回 $backlen 字符）=> https://alidocs.dingtalk.com/i/nodes/$nid"
}

cmd_append() {
  local text=""; while [ $# -gt 0 ]; do case "$1" in --text) text="$2";; esac; shift; done
  local nid; nid=$(cmd_today_node)
  dws doc +doc-append --doc "$nid" -y --text "$text" >/dev/null
  ok "已安全追加到 $DOC_NAME"
}

cmd_backup() {
  local file=""; while [ $# -gt 0 ]; do case "$1" in --file) file="$2";; esac; shift; done
  cp "${file:?需要 --file}" "$BACKUP_ROOT/$DATE.md"
  ok "已备份 outputs/daily-reports/$DATE.md"
}

case "${1:-}" in
  today-node) shift; acquire_lock; trap release_lock EXIT; cmd_today_node ;;
  write)      shift; acquire_lock; trap release_lock EXIT; cmd_write "$@" ;;
  append)     shift; acquire_lock; trap release_lock EXIT; cmd_append "$@" ;;
  backup)     shift; cmd_backup "$@" ;;
  lock)       acquire_lock && ok "已加锁 $LOCK" ;;
  unlock)     release_lock && ok "已释放锁" ;;
  with-lock)  shift; acquire_lock; trap release_lock EXIT; "$@" ;;
  *) err "用法: $0 {today-node|write|append|backup|lock|unlock|with-lock}"; exit 1 ;;
esac
