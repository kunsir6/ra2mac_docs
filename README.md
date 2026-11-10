# ra2mac_docs — ConcordRTS macOS 移植的项目管理文档库

这个仓库只装**过程与决策**，不装源码。源码在 `../ConcordRTS`（独立仓库），
游戏资产在 `../ConcordRTS-GameData`（不入库）。

建它的原因很直接：到 2026-11-11 为止，32 份报告散落在项目根目录、`progress/` 里的
队列与运行日志每小时都在变，而**它们一个都不在版本管理里**——源码有 `cdad6ab` 这样的
提交锚点，文档却只有文件系统的 mtime。事后要回答"当时为什么这么判断"，只能靠翻日志正文。

## 目录结构

```
ra2mac_docs/
├── reports/            各轮任务的说明与诊断报告（原在项目根目录，一字未改搬进来）
├── progress/
│   ├── queue.json      任务队列（机器可读，自动化每轮读写）
│   ├── RUNLOG.md       运行日志（每轮追加，标题格式即状态机）
│   ├── *.png           各轮取证截图
│   └── on-*-probe/     取证用的探针源码与抓图
├── report/             对外汇报用的 HTML
├── baseline/           Windows 侧基线数据（B-01 采集）
└── scripts/            辅助脚本（检查/统计类）
```

## 与项目根目录的兼容约定

自动化（每小时那轮）的提示词里写死了 `progress/queue.json` 与 `progress/RUNLOG.md`。
为了不动提示词、不中断已经跑了很久的流水线，项目根目录保留一个软链：

```
/Users/zhenglk/ai-project/ra2mac/progress -> ra2mac_docs/progress
```

所以两种路径都指向同一份文件，写到哪边都一样。**不要**把软链换成真目录，
否则自动化会写出第二份队列出来。

## 提交约定

- 一个逻辑动作一次提交，不要攒。文档的价值在"当时那一版"，攒成一坨就失去时间线。
- subject 用中文短句，前缀区分类型：
  - `docs:` 新增/修改报告
  - `queue:` 队列状态变更（任务推进、标 blocked、加规则）
  - `log:` RUNLOG 追加
  - `chore:` 结构整理
- 不提交：`.DS_Store`、`*.bmp` 临时转储、`progress/.active`（运行时心跳）、`__pycache__`。
- 截图该提交就提交（取证链断了比体积重要），单张超过 5MB 的先压一压再进。

## 和源码仓库的分工

| 仓库 | 管什么 | 谁提交 |
|---|---|---|
| `../ConcordRTS` | 源码、cmake、compat 层 | 自动化按"里程碑例外 / 族收口"规则提交 |
| `ra2mac_docs`（本仓库） | 报告、队列、运行日志、取证截图 | 每轮自动化收尾时一次 `docs:`/`queue:` 提交 |

源码仓库的提交规则里写着"报告 .md 与 progress/ 不纳入 git 提交"——那句话现在应理解为
**不进 ConcordRTS 仓库**，它们进本仓库。
