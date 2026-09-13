# 复刻指南（REPLICATION）

目标：在一台全新机器上，接入**你自己的钉钉知识库与机器人**，跑出一份和源环境一模一样的「工作日报自动化」。全程约 15~30 分钟。

---

## 0. 你需要先准备好

1. **一台机器**：macOS / Linux（Windows 用 WSL2 或 Git Bash）。
2. **运行时**：Node.js ≥ 18（含 npm）、Python ≥ 3.8、git、bash。
   - macOS：`brew install node python3 git`
   - Ubuntu：`sudo apt update && sudo apt install -y nodejs npm python3 git`
3. **一个钉钉企业内部应用（机器人）**：在钉钉开放平台创建「企业内部应用」，拿到 **AppKey(clientId) / AppSecret(clientSecret)**，并开通「钉钉文档/知识库/群消息」相关权限，把应用加入目标知识库（可编辑）。
4. **一个钉钉知识库**：用于存放日报。建议结构：
   ```
   你的知识库/
   └── 日常/
       ├── 日报/
       ├── 周报/
       └── 项目档案/
   ```
   （文件夹可先建好；没有也没关系，nodeId 发现与新项目脚本会协助。）
5. **一个有知识库读写权限的钉钉账号**：用它做 OAuth 授权（扫码）。

> 安全：AppSecret、OAuth token 只存在本机 `~/.dws/` 与本项目 `config/config.json`，两者都不进 git。

---

## 1. 拉取项目

```bash
git clone https://github.com/<你的账号>/daily-report-project.git
cd daily-report-project
```

## 2. 一键安装

```bash
bash scripts/install.sh
```

脚本会：
1. 检查 node/npm/python3/git；
2. 全局安装 dws CLI（`dingtalk-workspace-cli`）；
3. 从模板生成 `config/config.json`；
4. 引导你填钉钉应用 AppKey/AppSecret（写入 `~/.dws/app.json`，权限 600）；
5. 引导 OAuth 授权：
   - 本机有浏览器 → `dws auth login`
   - **SSH/无头服务器 → `dws auth login --device`**（显示验证码，用手机/浏览器授权，最稳）；
6. 若检测到 OpenClaw，询问是否把 `skill/` 安装到 `~/.openclaw/workspace/skills/daily-report`。

## 3. 配置知识库节点 ID

```bash
cp config/config.example.json config/config.json   # 若 install 没自动生成
bash scripts/discover-nodes.sh
```

脚本列出知识库根节点和「日常」的子节点，并直接打印可粘贴的值：

```
folder_daily_root       = 日常 的 nodeId
folder_daily           = 日报 的 nodeId
folder_weekly          = 周报 的 nodeId
folder_project_archive = 项目档案 的 nodeId
```

把这些连同 `workspace_id`、`reporter`（记录人姓名/抬头）填进 `config/config.json`。

## 4. 环境自检

```bash
bash scripts/check.sh
```

应看到：依赖齐全、`dws 已授权：<你的名字>`、日报文件夹可访问、项目档案文件夹可访问。

## 5.（可选）初始化项目名目录

四层体系要求每个项目在「项目档案」下有自己的文件夹：

```bash
bash scripts/new-project-folder.sh "示例项目"
```

它会：创建知识库文件夹 → 打印要补进 `config.json` 的 `project_folders` 行 → 提示在该目录下用模板建两份文档。
首次建文档示例：

```bash
# 拿到新目录 nodeId 后
dws doc create --name "示例项目｜问题与决策档案" --folder <项目目录nodeId> \
  --content-file skill/templates/project-archive-template.md
dws doc create --name "示例项目｜项目设计文档" --folder <项目目录nodeId> \
  --content-file skill/templates/project-design-doc-template.md
```

## 6. 开始用

### 方式 A：OpenClaw / 兼容 Agent（推荐）

`install.sh` 已把 `skill/` 装进 OpenClaw。新开会话，对 AI 说：

- 「写日报」—— 整理当前会话写入今天日报；
- 「根据 session 会话日志，补充日报」—— 上传/指向会话日志批量补充。

AI 会按 `skill/SKILL.md` 流程：认证检查 → 整理条目 → 加锁 → 找/建当天日报 → 归并 → 更新项目文档 → 备份+写入+校验。

> 注意：SKILL.md 内自带一份「固定常量/现有项目目录」示例（源环境的值）。复刻后请以你的 `config/config.json` 实际 nodeId 为准，或把 SKILL.md 常量段改成你自己的目录 ID。

### 方式 B：不用 Agent，纯命令行

```bash
# 打印/创建当天日报节点
bash scripts/daily-doc.sh today-node

# 你（或任何工具）产出合并好的 markdown 后，加锁备份+覆盖+校验：
bash scripts/daily-doc.sh backup --file /path/to/today.md
bash scripts/daily-doc.sh write  --file /path/to/today.md

# 覆盖失败时的安全兜底：
bash scripts/daily-doc.sh append --text "一条追加内容"
```

## 7. 脚本一览

| 脚本 | 作用 |
|---|---|
| `install.sh` | 装依赖、装 dws、配应用、授权、装 skill |
| `check.sh` | 环境与连通性自检 |
| `discover-nodes.sh` | 自动发现日常/日报/周报/项目档案 nodeId |
| `new-project-folder.sh "<名>"` | 新建项目名目录（四层第 3 层） |
| `daily-doc.sh` | today-node / write / append / backup / lock / with-lock |
| `common.sh` | 公共函数（被其它脚本 source） |

## 8. 与源环境的差异点（必须替换为你自己的）

| 项 | 源环境 | 你要改成 |
|---|---|---|
| 知识库 workspace_id / 各文件夹 nodeId | <你的公司>「战略部共享文档库」 | 你的知识库 |
| 钉钉应用 | <机器人名> AppKey/Secret | 你的企业内部应用 |
| OAuth 身份 | <记录人> | 你的账号（reporter 抬头同步改） |
| SKILL.md 现有项目目录 nodeId | 6 个源项目 | 你的项目（用 new-project-folder.sh 建） |
| 通知群 chatid / robotCode（可选） | 战略部消息群 | 你的群，或留空不通知 |

## 9. 常见问题

- **`dws` 命令找不到**：`npm i -g dingtalk-workspace-cli`，确认 npm 全局 bin 在 PATH。
- **SSH 授权回调打不开**：一定用 `dws auth login --device` 设备流。
- **报知识库不支持 drive 上传/建文件夹**：知识库节点要用 `dws wiki node create/list/move`，不要用 `dws drive mkdir/move`。
- **写日报锁被占用**：正常 1~2 分钟会释放；超过 10 分钟是死锁，脚本会自动清，或手删 `/tmp/daily-report-lock-<日期>`。
- **Windows（非 WSL）**：`stat -f`（macOS）/`stat -c`（Linux）有差异，建议用 WSL2；脚本对两种 stat 做了兼容，但 Git Bash 未完整测试。
- **日报建错文件夹**：检查 `config.json` 的 `folder_daily` 是否指向「日报」子文件夹而非「日常」根目录。

## 10. 升级

```bash
git pull
bash scripts/install.sh   # 会备份旧 SKILL.md 为 .bak 再更新
```
