#!/usr/bin/env bash
# install.sh —— 一键安装/复刻 daily-report 运行环境
# 作用：检查依赖 → 安装 dws CLI（npm）→ 准备配置 → 引导钉钉授权 → 安装 skill 到 OpenClaw（可选）
# 用法：bash scripts/install.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

echo "================================================"
echo "  daily-report 工作日报自动化 · 环境安装/复刻"
echo "================================================"

# 1) 基础依赖
log "检查基础依赖..."
missing=0
for c in node npm python3 bash git; do
  if require_cmd "$c" ""; then ok "$c"; else warn "缺少 $c"; missing=1; fi
done
if [ "$missing" = "1" ]; then
  err "请先安装上述缺失依赖（node 自带 npm；python3 ≥ 3.8）。"
  echo "  macOS:  brew install node python3 git"
  echo "  Ubuntu: sudo apt install -y nodejs npm python3 git"
  exit 1
fi

# 2) 安装 dws CLI（钉钉文档 CLI，公开 npm 包）
if command -v dws >/dev/null 2>&1; then
  ok "dws 已安装：$(dws version 2>/dev/null | head -1 || echo present)"
else
  log "安装 dws CLI（npm i -g dingtalk-workspace-cli）..."
  npm i -g dingtalk-workspace-cli
  ok "dws 安装完成：$(dws version | head -1)"
fi

# 3) 配置文件
if [ ! -f "$CONFIG_FILE" ]; then
  log "创建配置文件 config/config.json（从模板复制）..."
  cp "$PROJECT_ROOT/config/config.example.json" "$CONFIG_FILE"
  warn "请编辑 $CONFIG_FILE 填入你的知识库/文件夹 nodeId（可用 scripts/discover-nodes.sh 自动发现）。"
else
  ok "配置文件已存在：$CONFIG_FILE"
fi

# 4) 钉钉应用凭证（可选写入 ~/.dws/app.json）
if [ ! -f "$HOME/.dws/app.json" ]; then
  echo
  read -r -p "是否现在配置钉钉企业内部应用（AppKey/AppSecret）？[y/N] " yn
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    read -r -p "AppKey(clientId): " CID
    read -r -s -p "AppSecret(clientSecret): " CSEC; echo
    mkdir -p "$HOME/.dws"
    python3 - "$CID" "$CSEC" <<'PY'
import json, sys, os, datetime
cid, csec = sys.argv[1], sys.argv[2]
p = os.path.expanduser('~/.dws/app.json')
now = datetime.datetime.now().astimezone().isoformat()
json.dump({"clientId": cid, "clientSecret": csec, "createdAt": now, "updatedAt": now},
          open(p,'w',encoding='utf-8'), ensure_ascii=False, indent=2)
os.chmod(p, 0o600)
print("已写入 ~/.dws/app.json（权限 600）")
PY
  fi
fi

# 5) OAuth 授权
echo
if dws auth status --format json 2>/dev/null | grep -q '"authenticated": *true'; then
  ok "dws 已授权"
else
  warn "尚未授权 dws。"
  echo "  本机有浏览器：        dws auth login"
  echo "  SSH/无头/远程服务器： dws auth login --device   （推荐，显示验证码用手机/浏览器授权）"
  read -r -p "是否现在执行 dws auth login（默认设备流 --device）？[Y/n] " yn2
  if [[ ! "$yn2" =~ ^[Nn]$ ]]; then
    dws auth login --device
  fi
fi

# 6) 安装 skill 到 OpenClaw（可选）
OC_SKILL_DIR="$HOME/.openclaw/workspace/skills/daily-report"
if [ -d "$HOME/.openclaw" ]; then
  read -r -p "是否把 skill 安装/更新到 OpenClaw（$OC_SKILL_DIR）？[Y/n] " yn3
  if [[ ! "$yn3" =~ ^[Nn]$ ]]; then
    mkdir -p "$(dirname "$OC_SKILL_DIR")"
    if [ -d "$OC_SKILL_DIR" ]; then
      cp "$OC_SKILL_DIR/SKILL.md" "$OC_SKILL_DIR/SKILL.md.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    fi
    rm -rf "$OC_SKILL_DIR"
    cp -R "$PROJECT_ROOT/skill" "$OC_SKILL_DIR"
    ok "skill 已安装到 $OC_SKILL_DIR（旧 SKILL.md 如有已备份 .bak）"
    warn "注意：SKILL.md 内的 workspace/nodeId 常量需按你的 config.json 实际值核对修改。"
  fi
fi

mkdir -p "$BACKUP_ROOT"
echo
ok "安装流程结束。接下来："
echo "  1) 编辑 config/config.json 填 nodeId（先跑 bash scripts/discover-nodes.sh）"
echo "  2) 跑 bash scripts/check.sh 做环境自检"
echo "  3) 对 AI 说“写日报”，或在 OpenClaw 中触发 daily-report skill"
