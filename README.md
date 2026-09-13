# daily-report · 钉钉工作日报自动化

把每天在多个 AI 工作会话里干的事，自动整理成结构化**工作日报**写入钉钉知识库，并按项目长期沉淀**项目设计文档**与**问题与决策档案**。支持多会话并发写、四层文档体系、每日问题/异常闭环流转。

> 本仓库是一个**可完整复刻**的独立项目：在任何一台装了 Node + Python3 的机器上，按下方步骤即可部署出一份一模一样、接入你自己钉钉知识库的运行环境。

---

## 它能做什么

- 对 AI 说「**写日报 / 补充日报**」，即把当前（或指定 session 日志）会话的**最终情况**整理成标准条目写入钉钉当天日报。
- 多会话同时写不互相覆盖（本地原子写锁 + 读-改-写 + 写后校验）。
- 条目按 🔴 阻塞 > 🟡 进行中 > 🟢 已完成 排序，同一工作主线自动融合、不记流水账。
- **四层文档体系**：知识库 → 日常 → 项目档案 → **项目名目录** →（项目设计文档 + 问题与决策档案）。
- **每日异常流转**：日报问题摘要 → 项目《问题与决策档案》详细复盘 →《项目设计文档》风险登记册 / ADR 索引闭环。
- 面向不懂技术的读者：技术细节后必跟「小白话翻译」。

## 目录结构

```
daily-report-project/
├── skill/                      # OpenClaw / 兼容 Agent 的技能包（核心逻辑说明）
│   ├── SKILL.md                #   技能定义：触发词、流程、铁律、四层体系
│   └── templates/              #   日报 / 项目档案 / 项目设计文档 三套模板
├── scripts/                    # 可复用的命令行脚本（AI 或人都能调）
│   ├── install.sh              #   一键安装/复刻：装 dws、引导授权、装 skill
│   ├── check.sh                #   环境自检
│   ├── discover-nodes.sh       #   自动发现知识库 日常/日报/周报/项目档案 nodeId
│   ├── new-project-folder.sh   #   在项目档案下新建“项目名目录”（四层第3层）
│   ├── daily-doc.sh            #   日报机械操作：today-node/write/append/backup/lock
│   └── common.sh               #   公共函数（读 config.json、dws 封装、日志）
├── config/
│   ├── config.example.json     # 配置模板（复制为 config.json 填值）
│   └── config.json             # ⚠️ 你的真实配置，不入库（.gitignore）
├── docs/
│   ├── ARCHITECTURE.md         # 架构与四层文档体系说明
│   └── REPLICATION.md          # 手把手复刻指南（从零到可用）
├── outputs/daily-reports/      # 每次写入的本地备份（不入库）
├── package.json                # 声明 dws CLI 依赖，便于 npm 安装
├── .gitignore
└── LICENSE
```

## 快速开始（复刻到新机器）

```bash
# 1) 拉代码
git clone https://github.com/<你的账号>/daily-report-project.git
cd daily-report-project

# 2) 准备配置
cp config/config.example.json config/config.json

# 3) 一键安装（装 dws CLI、引导钉钉授权）
bash scripts/install.sh

# 4) 自动发现知识库文件夹 ID，填进 config/config.json
bash scripts/discover-nodes.sh

# 5) 环境自检
bash scripts/check.sh
```

完成后，在 OpenClaw 里对 AI 说「写日报」即可；没有 OpenClaw 也能用 `scripts/daily-doc.sh` 手工驱动。
完整图文步骤见 **[docs/REPLICATION.md](docs/REPLICATION.md)**，架构见 **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**。

## 前置条件

- macOS / Linux（Windows 建议用 WSL / Git Bash；`stat` 参数差异见 REPLICATION.md）
- Node.js ≥ 18（带 npm）、Python ≥ 3.8、git、bash
- 一个**钉钉企业内部应用（机器人）**的 AppKey/AppSecret，以及有该知识库读写权限的账号（OAuth 扫码授权）
- 一个用于存放的钉钉知识库（wiki），下建 `日常/日报`、`日常/周报`、`日常/项目档案` 文件夹

## 安全说明

- `config/config.json`、`~/.dws/`（含 AppSecret、OAuth token）**绝不入库**，已在 `.gitignore`。
- 仓库内**不含任何密钥/token**；复刻时用你自己的钉钉应用凭证。
- 日报铁律：不写银行卡、资金账户、身份证号等隐私。

## 许可

MIT
