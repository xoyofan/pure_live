# 上游同步审查 — 2026-10-02 冻结(未合并,处置 defer)

<!-- policy-markers: whole-diff-classification; merge-base-incoming-range; repository-audit-required; semantic-change-ledger; fork-feature-impact; disposition-required; bug-provenance-required -->

- 上游远端:`https://github.com/liuchuancong/pure_live.git`(新配置 `upstream`)
- 上游完整 SHA:`276fae8adf9be96f2edfba4182b5e394782529e2`
- 审查基线(fork HEAD):`63b0278c905b532b1c55078a99bd7d7da5ce0f6c`
- merge base:`5c453f6130c1a91d5550797c014cb5bdf5259d32`
- 门禁脚本实测(`tool/review_upstream_update.ps1 -BaseRef HEAD -UpstreamRef upstream/master`):**入站 109 提交 / 1292 文件 / 760 高风险**;入站 diff 自带尾随空格(shader/player_consts/services 层)被 `git diff --check` 拦截——属上游自身卫生问题,非凭据/安全形态,不触发硬阻断条款
- 试合并实测(`git merge --no-commit --no-ff` 后 abort):**88 个冲突文件**,分布 platforms 41 / features 18 / core 17 / app 3 / tool/probes 2 / services 2 / pubspec×2 / main.dart / modules / integration_test;DU 13(auth/firebase,fork 已删)· AU 22(rename 跟踪命中的新路径)· UU 50 · UD 1
- 结论:**本轮不合并**(处置 defer,理由见 disposition);master 保持干净,审查冻结入账

## file_review / whole-diff-classification

按主题归类入站 1292 文件(脚本 JSON 证据在 CI 入口 `Audit Upstream Update` 可复现,本地冻结口径一致):

| 主题 | 代表提交 | 文件面 | 类别 |
|---|---|---|---|
| 布局重构波①:站点适配器 `lib/core/site` → `lib/platforms/<site>/` | 0a931f51 | ~34 站目录整迁 | 重命名+移动 |
| 布局重构波②:旧 UI `lib/modules` → `lib/features/<域>` | d819a243/8a78ef81/4bfd8a33 | 全部 modules | 重命名+移动 |
| 布局重构波③:弹幕实现回站点目录,`core/danmaku` 只留空实现 | fbbccf36 | ~15 文件 | 移动 |
| 布局重构波④:`core/common` 拆 network/logging/streams/storage/links/publish | 4ec64e9e | ~20 文件 | 移动+改名 |
| 常量层:`core/interface` → `core/contracts`,`core/plugins` 拆解 | 501fc3d7/1e1cd8ad | ~30 文件 | 移动+改名 |
| 服务层/杂项归位:services、router bindings 合并、player 收敛、hygiene | 2d286bc0/1c4a971b/69316519/276fae8a 等 | ~200 文件 | 移动/合并/删除 12/改名 7/并入 9 |
| **接口重构:房间身份参数统一** `getRoomDetail(LiveRoom liveroom)` | 90a44712 | contracts/live_site + 全部适配器调用点 | 语义变更 |
| TV 壁纸(静态/动态/纯色渐变+解码器让位) | 5ef5a29b | 新功能目录+依赖 | 新增源 |
| 画中画增强:尺寸设置/悬停控件/拖角 resize/圆角/大播放钮 | 582e355f/f9e03f44/a51fc49a | player/presentation | 功能 |
| 弹幕:flame_barrage 补配置+按住定住;hideDanmaku 唯一开关;小窗弹幕配置合并 | 2d2ad203/d629b8b7/94ced49d/b2cca41c | danmaku 设置 | 功能+语义 |
| 播放器修复:切画质状态卡第一档(sourceSelection 丢于 facade) | 22579d3d | player facade | 修复 |
| 生命周期/设置修复:pip contain×2/全屏恢复窗口边界/小窗回直播间崩溃/字体设置启动崩溃/pip 失焦武装/驱动列表 auto | 2eef66b4/5ef91cc9/53384f97/06eac536/0b23cbb8/ecc931b3/8e9de7d9 | player/settings | 修复 |
| mpv 播放指南入口+版式 | 034bf35b/86b085c5 | settings UI | 功能 |

## semantic_change_ledger(逐主题)

| commit/file | upstream intent | issue_and_bug_mapping | implementation | quality_assessment | fork_feature_impact | disposition | regression_plan |
|---|---|---|---|---|---|---|---|
| 90a44712 LiveSite liveroom 参数化 | 房间身份(platform+roomId 双参)收敛为单 LiveRoom,消灭调用点拼参 | 上游内部重构,无外部 Issue | 接口+全部适配器+调用链改签名 | 方向正确;fork 侧 34 站(含 20 个上游没有的站)需同步迁移 | **高**:purelive_backend 桥接、tool/probes 全部探针、lib/src 4 文件导入点全要适配 | **defer**(随布局波专项) | 迁移专项验收=analyze 全仓+51 单测+全站播放/分类探针 |
| 布局波①-⑥(core→platforms/contracts/network…、modules→features) | 目录按职责分层,TV 词汇归一 | 上游内部重构 | 纯移动/改名/合并,内容少量随迁 | 对上游自洽;对 fork=1292 文件里 ~760 高风险全在此 | **高**:fork 解析层 94 提交定制(9 弹幕平台/分类中文化/bigo/17live/chzzk 等)与移动路径全面交叉 | **defer**:需专门迁移批次(内容三方合并+独有站整体搬迁+import 图迁移),非一次 merge 可安全完成 | 同上;另加真机播放抽验 |
| 22579d3d 切画质 sourceSelection 丢于 facade | 修复切档后状态卡第一档 | 上游播放器 bug | facade 透传 sourceSelection | 修复正确 | **无**(fork 播放链是 zishu play_provider,不经上游 facade;zishu 侧等价缺陷已在迭代13 修复) | **accept-记录**(随专项带入,无需独立动作) | 无 |
| 06eac536/0b23cbb8/ecc931b3/53384f97/2eef66b4/5ef91cc9/8e9de7d9 生命周期与设置修复 | pip/全屏/字体设置边界修复 | 上游 UI bug | 各自局部 | 均作用于 fork 运行时绕过的旧 UI(lib/features) | 低(编译单元需保持可编译) | **accept**(随专项带入) | 编译级验证 |
| 5ef5a29b 壁纸 / 582e355f+f9e03f44+a51fc49a pip 增强 / 2d2ad203 等弹幕功能 | TV/桌面旧 UI 功能 | 无 | 新依赖+新目录 | 上游自洽 | 中:pubspec 新增依赖(wallpaper 解码器等)需审查体积/平台支持 | **adapt**(依赖审查后随专项带入;zishu UI 不消费) | pubspec 冲突合并+编译 |
| d629b8b7/94ced49d hideDanmaku 唯一开关 | 弹幕显示配置收敛 | 上游内部 | 删除 enableDanmakuDisplay/enablePipDanmaku | 设置迁移需核对 | 低(旧 UI 设置) | **accept** | 设置迁移编译 |
| DU 13:features/auth(firebase) | 上游把 auth 移入 features | — | — | — | **fork 已按 AGENTS.md 移除 firebase 登录,不得重新引入** | **drop**(保持删除) | 确认合并树无 firebase 依赖回归 |

## fork_feature_impact 汇总

- **解析层(fork 核心资产)**:fork 在 merge-base 后 94 提交,含 9 平台弹幕全链路、34 站注册覆盖、分类中文化体系、bigo/17live/chzzk/twitcasting 解析修复——全部位于上游本次整迁的路径上;直接合并=41 个适配器三方冲突+20 个独有站滞留旧路径的混合布局。
- **zishu UI(lib/src)**:上游无此目录,零冲突;但 4 文件 10 个 `package:pure_live/core/*` 导入点随 contracts/platforms 迁移要改。
- **并行工作冲突**:owned-input 播放链接入(purelive_backend/play_provider/browse_source)正在进行中(63b0278c 刚落地 niconico),与合并的接口重构同文件,须串行。

## disposition

- **本轮:defer(布局重构波+接口参数化)**。恢复条件:① owned-input 播放链工作收敛并推送;② 开专门迁移批次(建议顺序:先 `git merge` 解 DU/AU(auth drop/内容三方合并)→ 独有 20 站搬迁 platforms+contracts 签名改写 → lib/src+packages+probes 导入迁移 → pubspec 依赖合并 → 全仓 analyze/测试/探针门禁);③ 每批一个提交可回滚。
- 行为修复/功能类(非布局):随迁移批次 accept/adapt 带入,不单独 cherry-pick(其文件已被上游后续布局提交移动,cherry-pick 会重复冲突)。
- auth/firebase:drop(硬口径,AGENTS.md)。

## conflict_resolution(试合并实测预案)

- `lib/platforms/**`(41 UU):上游版为底,叠加 fork 增量(missevan catalogs/soop Accept-Language/bigo liveStatus/chzzk 目录等)——迁移批次逐文件三方合并。
- `lib/features/auth/**`(13 DU):保持 fork 删除。
- `lib/core/**`(17 UU+22 AU):上游新分层为准,合入 fork 对 http_client(proxyDirective)/core_error 等的修改。
- `lib/main.dart`/`lib/app/**`:保 fork(zishu 入口+路由);上游 main 变更仅参考。
- `pubspec.yaml`/`pubspec.lock`:fork 版为底+上游新增依赖逐个审查后加入。

## regression_plan / verification_plan

迁移批次完成定义:全仓 analyze 零新增;51 fork 单测全过;`all_sites_playback_probe`/`all_sites_categories_probe`/`home_play_alignment_probe` 全站绿;`python tool/audit_repository.py` 全仓扫描;`git diff --check` 干净;真机 Windows 起播抽验(douyu/soop/missevan/17live 直达)。任何一步失败回滚该批次提交。
