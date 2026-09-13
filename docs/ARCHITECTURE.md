# 架构说明（ARCHITECTURE）

## 1. 定位

daily-report 是一个「AI 技能 + 命令行辅助脚本 + 钉钉知识库」的组合：

- **AI 负责"想"**：理解会话内容、提炼最终情况、判断同一主线、生成面向 +1 的条目文案、决定项目归类与风险等级。
- **脚本负责"做"**：加锁、查找/创建当天日报、覆盖写入、本地备份、写后校验、发现知识库节点 ID。
- **钉钉知识库负责"存"**：日报（按天）+ 项目文档（按项目，四层）。

AI 不可信地直接拼命令，机械、易错、需幂等的动作全部固化在 `scripts/` 里。

## 2. 四层文档体系

```
钉钉知识库（workspace）
└── 日常（folder_daily_root）
    ├── 日报（folder_daily）           每天一篇《YYYY-MM-DD 工作日报》
    ├── 周报（folder_weekly）          每周汇总（规划中）
    └── 项目档案（folder_project_archive）
            └── <项目名目录>/                    第 3 层：一个项目一个文件夹
                    ├── <项目>｜项目设计文档      第 4 层：架构蓝图+风险册+ADR（稳定）
                    └── <项目>｜问题与决策档案    第 4 层：问题/根因/决策/经验（追加）
```

- **项目设计文档**：背景/干系人/架构/数据/关键机制/部署/异常风控/配置速查/路线图/风险登记册/ADR 索引。相对稳定。
- **问题与决策档案**：每次报错、异常、事故的场景→根因→决策→技术细节+白话→经验；进度日志跨天追加。持续追加。
- **日报**：每个工作会话一条最终总结；项目类条目附该项目两份文档链接。

## 3. 每日异常流转

```
工作中出现问题/异常
 → ① 当天日报：条目（摘要 + 状态🔴🟡🟢 + 下一步 + 经验）
 → ② 项目《问题与决策档案》：详细复盘 + 进度日志一行
 → ③ 系统性/未决风险：登记《项目设计文档·风险登记册》
 → ④ 风险关闭：风险册标记关闭 + 决策进《ADR 索引》
 → ⑤ 引起架构/部署变化：更新设计文档对应章节
```

## 4. 组件与数据流

```
AI 会话（OpenClaw skill / 手工）
   │  读 skill/SKILL.md 流程
   ├─ dws auth status / login                 认证（OAuth，凭证在 ~/.dws）
   ├─ dws wiki node list/create/move          知识库文件夹（四层）
   ├─ dws doc +list / read / create / update  文档读写
   └─ scripts/daily-doc.sh                     加锁→查找/建当天日报→覆盖→备份→校验
         └─ 读 config/config.json（workspace/folder nodeId）
         └─ 本地 outputs/daily-reports/YYYY-MM-DD.md 备份
         └─ /tmp/daily-report-lock-YYYY-MM-DD 原子写锁
```

## 5. 并发与一致性

- **写锁**：`mkdir` 原子锁 `/tmp/daily-report-lock-<日期>`，多会话串行化"读-改-写"；持锁进程退出自动清理；死锁 10 分钟强制释放。
- **覆盖写**：AI 先 `read` 云端最新全文 → 在内存归并 → `update --mode overwrite --yes` 整篇写回；云端已有事实只融合不删改。
- **兜底**：覆盖失败降级 `dws doc +doc-append` 安全追加，保证不丢内容。
- **写后校验**：重新 `read`，确认本次条目在、无重复。
- **本地备份**：每次合并后完整 markdown 存 `outputs/daily-reports/`。

## 6. 依赖

| 依赖 | 作用 | 安装 |
|---|---|---|
| dws（dingtalk-workspace-cli） | 钉钉文档/知识库 CLI | `npm i -g dingtalk-workspace-cli`（install.sh 自动装） |
| Node.js ≥18 | dws 运行时 | 系统包管理器 |
| Python ≥3.8 | 脚本解析 JSON、生成骨架 | 系统包管理器 |
| git | 版本管理 | — |

> dws 是公开 npm 包，自带各平台二进制；认证数据在 `~/.dws/`，与本仓库完全分离。

## 7. 配置项（config/config.json）

| 键 | 含义 |
|---|---|
| workspace_id | 知识库 ID |
| folder_daily_root / folder_daily / folder_weekly / folder_project_archive | 四层所需的文件夹 nodeId |
| reporter.name / doc_byline | 日报记录人抬头 |
| project_folders | 项目名 → 项目名目录 nodeId（new-project-folder.sh 自动产出） |
| dingtalk_app.* | 你自己的钉钉应用凭证（写入 ~/.dws/app.json，不入库） |

## 8. 安全边界

- 不含、也不提交任何 token / AppSecret / cookie。
- `config.json`、`outputs/`、`~/.dws/` 均不入库。
- 只写真实发生的事；隐私红线字段不写。
