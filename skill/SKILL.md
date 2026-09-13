---
name: "daily-report"
description: "工作日报写入钉钉共享文档。说\"写日报/补充日报\"时触发，按模板写入钉钉当天日期文档，多会话合并，含并发写锁。"
---

# 工作日报 Skill（daily-report）

把**<记录人>**当天的工作写入钉钉共享文档，双轨归档：

- **日报（按天流水）**：「战略部共享文档库」→「日常」文件夹，每天一篇 `YYYY-MM-DD 工作日报`。
- **项目档案（按项目沉淀）**：「战略部共享文档库」→「项目档案」文件夹，每个长期项目一篇，跨天更新。
  日报中项目类事项必须引用对应档案链接。

## 使用方式（重要）

<记录人>**下班前在当天每个工作会话中各执行一次**本 skill。每次调用：

- 整理**当前这个会话从头到尾的最终情况**（做了什么、解决了什么、最终状态、下一步），
  写成**一个日报条目**——不需要过程时间线，读者要的是这个会话的最终结果全貌。
- 写入当天日报：若该会话的事项与日报中已有条目是**同一工作主线**（如同一项目），
  则把内容融合进已有条目并更新为最新状态；否则作为新条目加入。
- 不同会话处理不同事项时，日报中就是各自独立的条目并列。

## 使用人与身份

- **日报记录人/使用人：<记录人>**（唯一使用人）。文档抬头写"<记录人>（由 AI 助手整理）"。
- dws OAuth 写入身份也是<记录人>（<机器人名>）。不要写成<使用者>或其他人。

## 固定常量

- 知识库「战略部共享文档库」workspaceId：`<YOUR_DINGTALK_KNOWLEDGE_WORKSPACE_ID>`
- 「日常」文件夹 nodeId：`<YOUR_DAILY_FOLDER_NODE_ID>`（日报/周报/项目档案的父目录）
- **日报文件夹「日常/日报」nodeId：`<DINGTALK_DAILY_FOLDER_NODE_ID>`**（日报必须写这里；2026-09-08 更正，旧常量 a9E05… 是「日常」根目录，会把日报建错层级）
- 周报文件夹「日常/周报」nodeId：`<DINGTALK_WEEKLY_FOLDER_NODE_ID>`
- 项目档案总文件夹 nodeId：`<YOUR_PROJECT_ARCHIVE_FOLDER_NODE_ID>`（即「日常」下的「项目档案」子文件夹；旧值 <OLD_PROJECT_ARCHIVE_NODE_ID> 已失效会报 RESOURCE_NOT_FOUND，2026-09-04 更正）。
- **【四层体系，2026-09-09 起】** 知识库→日常→项目档案→**项目名目录**→文档。项目档案总文件夹下按项目建子目录，每个项目目录内存放该项目的两类文档：`<项目名>｜项目设计文档`（架构/设计，相对稳定）+ `<项目名>｜问题与决策档案`（问题/异常/决策流水，持续追加；部分旧文档名为 `<项目名>项目档案`）。知识库节点操作用 `dws wiki node ...`（drive mkdir/move 对知识库不适用）。现有项目目录 nodeId：
  - `<内部项目名A：订单补单自动化>` → `<DINGTALK_NODE_ID_1>`
  - `<内部项目名B：订单客审拦截>` → `<DINGTALK_NODE_ID_2>`
  - `<内部项目名C：客服微信群机器人>` → `<DINGTALK_NODE_ID_3>`
  - `<内部项目名D：数据看板>` → `<DINGTALK_NODE_ID_4>`
  - `<内部项目名E：日报文档体系>` → `<DINGTALK_NODE_ID_5>`
  - `<内部项目名F：月度规划>` → `<DINGTALK_NODE_ID_6>`（规划类，非技术项目）
  - 新项目：先 `dws wiki node create --workspace <YOUR_DINGTALK_KNOWLEDGE_WORKSPACE_ID> --name "<项目名>" --type folder --folder <YOUR_PROJECT_ARCHIVE_FOLDER_NODE_ID>` 建目录，再在其下建两份文档。
- 文档命名：日报 `YYYY-MM-DD 工作日报`；项目内文档 `<项目名>｜项目设计文档` / `<项目名>｜问题与决策档案`
- 本地备份：`outputs/daily-reports/YYYY-MM-DD.md`、`outputs/daily-reports/project-<项目名>.md`
- 本地写锁：`/tmp/daily-report-lock-YYYY-MM-DD`（mkdir 原子锁）

## 铁律

1. **只写真实发生的事**：只从当前会话上下文（用户消息、实际工具调用与结果）提取，绝不编造
   动作、数据、人名、结论。信息不足写「待补充」或写完后一次问清。
2. **一个会话 = 一个条目，写最终情况**：条目呈现该会话工作的最终全貌（问题、方案、结果、状态），
   不写过程时间线、不记流水账。同一主线跨会话时融合为一条，状态取最新。
3. **面向 +1 写作**：问题按"场景→影响环节→风险"讲；方案写"怎么做+为什么+技术细节+小白话翻译"。
4. **经验/收获/注意事项字段必须保留**（使用人明确要求）。
5. **【明确目录】**：日报开头注明归档位置；项目类事项必须附项目文档链接（设计文档 + 问题与决策档案两份）。
6. 状态排序固定：🔴 阻塞项 > 🟡 进行中 > 🟢 已完成（条目状态取主线最新状态）。
7. 隐私红线（银行卡、资金账户、身份证号）不得写入。
8. dws 命令加 `--format json`；写操作加 `-y`；overwrite 必须显式 `--yes`。
9. 云端已有内容以文档为准，归并时不得删改其他会话写入的事实。

## 四层文档体系与每日异常流转（2026-09-09 起由三层升级）

**目录层级**：知识库 → 日常 → 项目档案 → **项目名目录** → 两份项目文档。

每个项目目录内有**两份文档**，职责不同：
- **《<项目>｜项目设计文档》** = 架构蓝图+台账（相对稳定）：背景/干系人/架构/数据/关键机制/部署/异常风控/配置速查/路线图/**风险登记册**/**关键决策索引(ADR)**。模板 `templates/project-design-doc-template.md`。
- **《<项目>｜问题与决策档案》** = 病历本（持续追加）：每次报错/异常/事故的场景、现象、根因、决策、技术细节+白话、经验，以及进度日志。模板 `templates/project-archive-template.md`。

**每日问题/异常的流转路径**：
1. 当天日报写一条目（问题摘要+状态 🔴/🟡/🟢 + 下一步 + 经验）；
2. 项目类问题 → 追加到该项目《问题与决策档案》（详细复盘 + 进度日志一行）；
3. 若暴露**系统性/未决风险** → 登记到《项目设计文档》第 13 节「风险登记册」（🔴/🟡/⚪ + 影响 + 对策 + 负责人）；
4. 风险解决后 → 风险登记册标记关闭，决策摘要进设计文档第 14 节「ADR 索引」；
5. 若问题导致架构/模块/部署变化 → 更新设计文档对应章节。

日报条目里项目类事项的链接区同时放：设计文档链接 + 问题与决策档案链接。

## 执行流程

### Step 0：前置检查
`dws auth status --format json` 确认 authenticated；失败提示 `dws auth login`，不要继续。

### Step 1：整理当前会话的最终情况
- 日期默认今天（Asia/Shanghai）。回顾**整个当前会话**，提炼：
  - 这个会话处理了什么工作/解决了什么问题（一条主线；若会话明显处理了两件不相关的事，可拆两条）
  - 最终结果与状态（已完成/进行中/阻塞）
  - 关键决策及原因、技术细节、涉及人/系统、下一步、经验收获
  - 纯闲聊/咨询不写入。
- 项目判定：跨天持续、有项目名、反复迭代 = 项目类（同步项目档案）；一次性日常处理 = 只进日报。
- 按下方条目格式组织，面向不懂技术的 +1：技术细节后紧跟小白话翻译。

### Step 2：加本地写锁
多个会话可能同时调用，mkdir 原子锁串行化"读-改-写"：

```bash
LOCK=/tmp/daily-report-lock-$(date +%F); acquired=0
for i in $(seq 1 60); do
  if mkdir "$LOCK" 2>/dev/null; then echo $$ > "$LOCK/pid"; acquired=1; break; fi
  if [ -d "$LOCK" ] && [ $(( $(date +%s) - $(stat -f %m "$LOCK" 2>/dev/null || echo 0) )) -gt 600 ]; then rm -rf "$LOCK"; continue; fi
  sleep 2
done
[ "$acquired" = "1" ] || { echo "写锁被占用，请 1 分钟后重试"; exit 1; }
trap 'rm -rf "$LOCK"' EXIT
```

### Step 3：处理项目文档（项目类事项才做，四层体系）
1. **定位项目目录**：`dws wiki node list --workspace <YOUR_DINGTALK_KNOWLEDGE_WORKSPACE_ID> --folder <YOUR_PROJECT_ARCHIVE_FOLDER_NODE_ID> --format json`
   查「项目名目录」（nodeId 见上方固定常量）。
   - 新项目目录不存在 → `dws wiki node create --workspace <YOUR_DINGTALK_KNOWLEDGE_WORKSPACE_ID> --name "<项目名>" --type folder --folder <YOUR_PROJECT_ARCHIVE_FOLDER_NODE_ID>` 建目录，并把 nodeId 补进 SKILL 常量。
2. **查项目目录内两份文档**：`dws doc +list --folder <项目目录nodeId> --limit 50 --format json`
   - 《<项目名>｜问题与决策档案》：不存在 → 按 `templates/project-archive-template.md` 用 `dws doc create --folder <项目目录nodeId> --content-file` 新建。
   - 《<项目名>｜项目设计文档》：仅当本次涉及架构/新项目时才建，模板 `templates/project-design-doc-template.md`（不是每次写日报都动设计文档）。
3. **更新问题与决策档案**：已存在则 read 全文，把本次会话最终情况合并进对应章节（问题清单、决策记录、
   进度日志追加一行 `YYYY-MM-DD：当天最终进展摘要`、状态更新），整篇写回。
4. **风险/架构变化**：未决系统性风险 → 更新设计文档「风险登记册」；决策闭环 → 「ADR 索引」；架构/模块/部署变化 → 对应章节。
5. 记录项目目录内两份文档的链接供日报引用。

### Step 4：查找并读取当天日报
`dws doc +list --folder <DINGTALK_DAILY_FOLDER_NODE_ID> --limit 50 --format json` 找
`YYYY-MM-DD 工作日报`；存在则 `dws doc read` 取全文。

### Step 5a：日报不存在 → 新建
按 `templates/daily-report-template.md` 填写（长内容 --content-file）：
`dws doc create --name "YYYY-MM-DD 工作日报" --folder <DINGTALK_DAILY_FOLDER_NODE_ID> --content-file <file> --format json`
失败降级 `--workspace <YOUR_DINGTALK_KNOWLEDGE_WORKSPACE_ID>` 后 `dws doc +move` 移入「日常/日报」文件夹。

### Step 5b：日报已存在 → 归并
1. 在现有 🔴🟡🟢 分区中找**同一工作主线**的条目（按项目名/事项主题判断）。
2. 同一主线 → 把本次会话内容**融合**进该条目：【问题及影响】【处理和决策方案】补充新内容
   （不重复已有）、状态更新为最新（条目随状态在分区间移动）、关键结果/下一步/经验同步更新、
   补项目档案链接。**不开新条目、不加时间线。**
3. 不同事项 → 作为新条目插入对应状态分区。
4. 判断不准时倾向融合到最接近的条目，并在回复中说明"已并入 XX"；用户明确说是另一件事才新开。
5. 全文按 🔴>🟡>🟢 重排；明日计划合并去重；头部"更新记录"追加 `第N次写入 · HH:MM · <会话主题>`；
   今日概览同步更新（条目数量、统计）。

### Step 6：备份 + 写入 + 校验
1. 合并后完整 markdown 存本地 `outputs/daily-reports/`（项目档案同样存一份）。
2. 写临时文件后 `dws doc update --node <nodeId> --content-file <file> --mode overwrite --yes --format json`。
3. 失败降级 `dws doc +doc-append --doc <nodeId> -y --text "<本次条目>"` 安全追加，保证不丢。
4. 写后 `dws doc read` 校验：本次条目内容在、无重复条目。trap 自动释放锁。

### Step 7：回复
告知：本次会话整理成了哪个条目（新开 / 已并入哪条）、条目状态、日报链接、项目档案链接（如有）。
有「待补充」字段一次问完。IM 渠道给链接即可。

## 事项条目格式（日报中使用）

```markdown
- **事项**：<工作主线/项目名>
  - **【问题及影响】**：<场景：什么问题、影响哪个环节、不修的风险>
  - **【处理和决策方案】**：<最终怎么处理的 + 为什么这样决策；技术细节（命令/文件/数据/机制）+
    小白话翻译；日报写摘要，完整细节放项目档案>
  - **涉及人/部门/系统**：<>
  - **状态**：<已完成/进行中/阻塞>（取最新）；阻塞项加"阻塞原因与需要谁解决"
  - **📁 项目档案**：<项目类必填：目录名 + 链接>
  - **下一步**：<动作+负责人+时间点>
  - **经验/收获/注意事项**：<必填>
```

## 项目档案格式

见 `templates/project-archive-template.md`：项目一句话说明 →【问题及影响】（按场景）→
【处理和决策方案】（方案+为什么+技术细节+小白翻译）→ 关键信息速查表 → 进度日志（跨天追加）→ 经验收获。

## 注意事项

- 技术细节与小白翻译成对出现：先术语后比喻。
- 条目写"最终情况"而非过程：会话中试错/迭代的过程浓缩为结果与经验，不铺陈步骤。
- 下班前最后一次调用后，日报应呈现：当天每个工作会话一条最终总结，🔴>🟡>🟢 排序，无重复无流水账。
- dws 用法以 `dws <cmd> --help` 现场输出为准；失败先 `--verbose` 重试，再按
  dws-cli / dingtalk-troubleshoot 处理。
