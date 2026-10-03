# 上游同步审查 — 2026-10-03 冻结并合并(处置 accept,双原则)

<!-- policy-markers: whole-diff-classification; merge-base-incoming-range; repository-audit-required; semantic-change-ledger; fork-feature-impact; disposition-required; bug-provenance-required -->

- 上游远端:`https://github.com/liuchuancong/pure_live.git`(既有 `upstream`)
- 上游完整 SHA:`b087ee901eb35b568ec91bcedd2c259428f4c6f3`
- 审查基线(fork HEAD):`c40cdedbb96cf45f8ee9ea8a5f30ad0835baf5cf`(17LIVE 媒体头修复)
- merge base:`276fae8adf9be96f2edfba4182b5e394782529e2`(上一轮合并点)
- 入站范围:`276fae8a..b087ee90` = **127 提交 / 621 文件(+13888/−6763;新增 59·删除 11·修改 128·更名 423)**
- 门禁脚本实测(`tool/review_upstream_update.ps1`):`violations=[]`(无凭据/可变引用/pull_request_target/write-all 形态;新增 architecture.yml 权限 contents:read、action 固定 40 位 SHA,政策合规)。`diff_check_passed=false` 系入站 diff 自带尾随空格(domains/shared/layout 波的生成文件)——**上游自身卫生问题,非硬阻断条款**,与上轮 276fae8a 同性质(该轮证据 `local-artifacts/upstream-reviews/upstream-276fae8adf9b.json` 同为 false,已按先例放行+合并后 fork 侧格式化)。脚本 JSON 的 commits 列表因 PowerShell 管道丢行只含 59 条;本审计以命令行 `git log` 全量 127 条为准(为其超集,校验覆盖)
- 试合并实测(`git merge --no-commit --no-ff` 后 abort):**94 个未合并文件** = UU 46 · AU 24 · DU 13 · UA 5 · DD 5 · UD 1;自动合并成功面 372 更名/114 修改/63 删除/59 新增
- 结论:**本轮合并**(处置 accept);冲突按双原则解决——解析层跟上游(purelive),UI 以 fork zishu 为准;版本/构建/更新源/firebase 删除边界保持 fork 不变量

## file_review / whole-diff-classification

全部 621 文件逐字清单见**附表B**(按顶层目录分组,含更名前后路径);全部 127 提交逐字清单见**附表A**。主题归类:

| 主题 | 代表提交 | 文件面 | 类别 |
|---|---|---|---|
| **分层架构波②**:`lib/platforms`→`lib/shared/platforms`、旧 UI `lib/features`→`lib/domains/<域>`、core 拆 config/navigation/platform/player/stream/theme、新建 `shared` 层 | f4a5f7b6/5e74893f/77895fa7…e1475e9a(约 20 提交) | ~450 更名 + core 新骨架 | 重命名+移动 |
| **架构门禁**:`tool/validate_architecture.py`(BASELINE 登记 38 处既有耦合)+`.github/workflows/architecture.yml`(strict,push/PR 触发) | 20817480/e1475e9a | 新增 3 文件 | 新增源+工作流 |
| **"摘取 4.x"平台大波**:受限直播口径(LiveRestriction 七类)/开播时间(startedAt)/B站轮播 carousel/douyin 游戏分区·精确在线/huya UA·付费标/kuaishou H.265 档/twitch 图片直连/soop HTML 实体/chzzk 频道链接搜索/pandalive IVS 租约/…约 40 提交按站落 | 907a34d3/489aaf85/ac69fc2c/50fe8ffe/5a13f924/2f57b28d/b3e26747/cba9fbd3/3c3322df/35bfc074/… | shared/platforms 全站 | 语义变更 |
| **弹幕大功能**:`LiveMessage.emotes`+`LiveEmote`(表情图片)/`LiveMessageType.retraction`+`LiveRetraction`(撤回)/礼物进列表/平台公告进列表/打码昵称屏蔽修复/huya 结束弹幕修复 | 43540cc1/89248f0f/0533df81/db09fc21/4966ca1c/c4699764/f587c26a/9fb1ef1d/c217b86b/dffed3f6/6e79b8bd/133725ed/fcdbd588 | model+engine+bilibili/kuaishou 站点 | 语义变更 |
| **壁纸域**:`lib/domains/wallpaper/`(随机图源数据层/分页/预览/卡片底色跟随/标题栏延伸/防闪白) | 5d29713b/813123a6/54b4d92d/f641c851/dd1fa503/2a3a713a/… | 新增域 12 文件 | 新增源(旧 UI) |
| **pip/悬浮窗/多画面**:Windows 小窗解锁比例/几何横竖屏两套/弹幕内缩/多画面有声无画修复/全屏进出交内核呈现链 | 9a845e69/e96878ae/dc729850/753bbbb7/234df47a/e437b5bd | player/presentation | 功能+修复 |
| **B站轮播起播偏移**(第1-3步)/niconico 主播链接可打开(身份仍是节目号) | 4291990b/07a91cd1/bb1f6fba/abb4c726 | bilibili+domains | 功能 |
| **开播时间波**:bilibili/douyu/douyin/twitch/acfun/seventeen/showroom/inke/cc → startedAt | 02174149/5d187d7c/c23cff07/ec327f40/183cd2ab/4cb81403/ffd53aee/adcfd0c0/bbc0ef44 | 各站 | 语义变更 |
| **杂项**:MI Sans 全局默认字体/收藏失败日志合并/favorite 勾选/导入排序 | d8b8719f/7e90a15e/41ec1fcb/a7783b52/f7c61d4f | theme/features | 功能+polish |
| **模型/契约**:`LiveStatus.carousel`(追加尾位,持久化兼容)/`LiveRestriction`(按名持久化)/invisible_placeholders 不可见字符清理/LiveRoomVolumeStore import 路径随迁 | 15c72a90/654acc89 | core/models+utils | 语义变更 |

## semantic_change_ledger(逐主题)

| commit/file | upstream intent | issue_and_bug_mapping | implementation | quality_assessment | fork_feature_impact | disposition | regression_plan |
|---|---|---|---|---|---|---|---|
| f4a5f7b6…e1475e9a 分层波② | 站点适配器上移 shared、旧 UI 进 domains、core 收缩为纯基座;跨域反向依赖 61→21 并以 CI 卡新增 | 上游内部重构,无外部 Issue | 纯移动/更名为主,随迁少量 import 修复 | 对上游自洽;fork 侧 fork-only 文件(11 平台弹幕/proto/zishu lib/src)零冲突或伪冲突(AU=rename 检测拖拽) | fork 94 提交定制全部在迁移路径上;fork 独有文件随迁新路径 | **accept**(布局随上游) | 全仓 analyze+全量测试+audit_repository |
| 20817480 validate_architecture.py | 分层反向依赖 CI 门禁,BASELINE 登记既有耦合 | 上游内部治理 | 静态 import 图检查,--strict 拒新增 | 依赖上游目录形状;fork 增量文件若触发 BASELINE 外耦合需登记或修复 | fork 的 lib/src(zishu)/tool/probes 需本地验证不误伤 | **accept**+本地跑通(必要时登记 fork 增量) | python tool/validate_architecture.py --strict |
| 907a34d3 B站轮播/15c72a90 LiveRestriction/开播时间波 | 平台"为什么不能播"统一口径:列表在播+播放时说明;轮播房从 offline 分离;startedAt 全站透出 | 上游 4.x 功能同步(其 PLATFORM_SYNC_LEDGER_4X.md 台账) | LiveStatus.carousel(枚举尾位追加,JSON index 兼容)/LiveRestriction(按名持久化)/各站解析填充 | 模型演进正确;枚举追加+按名持久化均有兼容说明 | fork purelive 桥 `pureliveRoomToPayload` 需透传新字段;旧 UI 编译单元随之更新 | **accept** | 桥接层单测+全站播放探针 |
| 弹幕大功能(43540cc1…133725ed) | 表情图片/撤回/礼物/公告四类消息形态打通到列表+画面 | 上游 4.x 弹幕增强 | LiveMessage 新字段(emotes/retraction)+引擎按条撤回(retractWhere)+列表/画面渲染 | 跨层契约清晰;engine 依赖 flame_barrage 未发布接口 | **fork 侧 zishu 弹幕渲染走自家链**,上游改动作用于旧 UI 编译单元;zishu 可后续消费契约 | **accept**(flame_barrage 依赖 **adapt**) | 全量测试(弹幕协议单测 60+ 用例) |
| 壁纸域(5d29713b…2a3a713a) | 随机图源/分页/预览/底色跟随/防闪白 | 上游 4.x 功能 | lib/domains/wallpaper 12 文件+设置接线 | 新域自洽;zishu UI 不消费 | 仅旧 UI 编译单元;zishu 零影响 | **accept** | 编译级+全量测试 |
| pip/多画面/全屏修复(9a845e69/753bbbb7/234df47a 等) | 小窗比例解锁/几何记忆/多画面修复/全屏交内核呈现链 | 上游桌面 bug 修复 | player/presentation 局部 | 均作用于 fork 运行时绕过的旧 UI | 低(编译单元) | **accept** | 编译级 |
| DU 13:domains/account/auth(firebase) | 上游把 auth 移入 domains | — | — | — | **fork 已按 AGENTS.md 移除 firebase,不得重新引入** | **drop**(保持删除) | 确认合并树无 firebase 依赖回归 |
| DD 5(core/link、core/widgets/room_card、player/core/playback_header_resolver、douyin/proto) | 双方各自迁走同一批文件 | — | — | — | 无(路径对齐) | **accept 双删** | 路径核对 |
| UD 1:lib/services/settings_service.dart | 上游移至 lib/core/config/settings_service.dart | — | 移动 | — | fork 定制 `SettingsService.maybe`(迭代14B,zishu 运行时安全访问)必须回植 | **adapt**(受移动+回植 maybe) | settings_service_maybe_test |
| pubspec:flame_barrage `path: E:/software/flame_barrage` | 撤回需未发布的 retractWhere 接口 | — | 本地绝对路径依赖 | **不可直接取用**(上游作者本机路径);fork 先例=克隆至本机固定路径(media_core→F:/media_core 同款) | 需克隆上游 flame_barrage 仓到 F:/flame_barrage 并改 pubspec 指向 | **adapt**(F:/ 路径) | pub get+编译 |
| MI Sans(d8b8719f) | 全局默认字体 | — | assets/fonts+theme | 1.9MB 字体资产 | 旧 UI+zishu 共享 theme 时生效;zishu 自有字体栈不受迫 | **accept** | 编译级 |
| AU 24(fork-only:11 平台弹幕+proto+core/network/playback_header_resolver 等) | 上游未触碰这些内容;冲突系 rename 检测把 fork 新目录拖入上游同名目录迁移 | — | — | 伪冲突 | fork 资产原样随迁 shared/ 新路径 | **accept(取 fork 内容,放上游新路径)** | 全量测试(11 平台弹幕协议单测) |

## issue_and_bug_mapping

- 上游本波无对外 Issue 映射(全部为 4.x 功能同步+内部重构);上游自带台账 `docs/PLATFORM_SYNC_LEDGER_4X.md` 一并入站,作为上游侧语义索引。
- 与 fork 台账的交叉:上游 `ac69fc2c` huya 搜索 UA 修复与 fork 迭代28 虎牙 getLiveList 切换不冲突(不同端点);上游开播时间波与 fork 迭代28 斗鱼 startedAtMs 暂存字段**同目标不同实现**——fork 走 betard show_time 暂存 data,上游走 startedAt 字段直出;合并后两路并存,fork 桥接层 `payload.startedAt` 口径不变(取上游字段优先,暂存兜底,在合并时核对)。
- PandaTV/CHZZK 弹幕待网络验收、Bigo 匿名门等 fork 台账既有项不受本波影响。

## fork_feature_impact 汇总

- **解析层(34 站,fork 核心资产)**:上游"摘取 4.x"波直接修改同批站点文件(UU 20 站)——解决规则=**上游为底,git merge-file 三方合成回植 fork 语义补丁**(missevan catalogs/soop en-US+进程表/bigo liveStatus/chzzk 真目录/twitch·kuaishou·soop·yy maybe/斗鱼抖音 ParserConfig/迭代28 暂存字段/huya getLiveList)。fork-only 20 站(上游没有的适配器)随目录迁移整体搬入 `lib/shared/platforms/`。
- **桥接层(purelive_backend)**:上游新字段(startedAt/restriction/carousel/emotes)经桥接透传需补接;fork 头部契约委托(迭代31)文件(core/network/playback_header_resolver)为 AU 伪冲突,取 fork。
- **zishu UI(lib/src)**:上游零触碰;仅 packages/live_parser 无上游改动(fork 反多 remap 导出)。zishu 对上游新模型(carousel/restriction)默认不渲染,后续按需立项消费。
- **旧 UI(lib/features→lib/domains)**:整波接受,保持可编译(zishu 运行时绕过)。
- **版本/构建/发布**:pubspec version 保持 fork 3.1.18+4107;assets/version.json 不取上游;flame_barrage 路径 adapt 为 F:/。

## quality_assessment

- 模型演进(carousel 枚举尾位/restriction 按名持久化)自带向后兼容说明,追加式演进正确。
- 架构门禁 BASELINE 机制合理(卡增量不追旧账);fork 需本地验证 --strict 通过或登记 fork 增量。
- 上游文件卫生(尾随空格/EOF 空行)由 fork 侧 dart format 改动文件消化。
- flame_barrage 本地路径依赖是上游仓库的可移植性债务,fork 按既有 media_core 先例处理。

## disposition

分层架构波②/架构门禁/"摘取 4.x"平台波/弹幕大功能/壁纸域/pip·多画面修复/开播时间波/B站轮播/niconico 链接/MI Sans/模型演进 = **accept**;
flame_barrage 路径依赖/settings_service 移动+maybe 回植/fork-only 文件随迁 = **adapt**;
firebase auth 13 文件 = **drop**(保持删除);
无 rewrite/defer 项。

## conflict_resolution

94 个未合并文件的处置分类:

1. **DD 5**(双方迁走):保持删除——`lib/core/link/live_url_tool.dart`、`lib/core/link/shared_live_link_opener.dart`、`lib/core/widgets/room_card.dart`、`lib/platforms/douyin/proto/douyin.proto`、`lib/player/core/playback_header_resolver.dart`。
2. **DU 13**(fork 删除×上游改动):保持删除(firebase/auth 边界)——`lib/domains/account/presentation/auth/**` 13 文件。
3. **UD 1**:取上游移动版 `lib/core/config/settings_service.dart` + 回植 fork `maybe` 访问器;旧路径保持删除。
4. **UA 5**:取上游新路径版本(`lib/domains/live/data/link/*`、`lib/domains/live/data/playback_header_resolver.dart`、`lib/domains/live/presentation/widgets/room_card.dart`、`lib/shared/platforms/douyin/proto/douyin.proto`),旧路径随 DD 保持删除。
5. **AU 24**(fork-only 资产):取 fork 内容放上游新路径——11 平台弹幕+acfun/douyin proto → `lib/shared/platforms/<site>/`;`lib/core/network/playback_header_resolver.dart`(fork 迭代31 头部契约)取 fork;`lib/core/config/parser_runtime_binding.dart`、`lib/core/player/core/features_bridge.dart`、`lib/domains/live/presentation/playback/controllers/player_room_context_bridge.dart`、`lib/features/link/shared_live_link_opener.dart`、`lib/features/live/widgets/room_card.dart` 取 fork(上游无对应内容或 fork 定制)。
6. **UU 46**(真三方):站点适配器 20 处按"上游为底+git merge-file 回植 fork 补丁";core/models/live_room.dart、core/network/douyu_utils/http_client、main.dart(fork zishu 入口为准,仅吸收上游运行时必需接线)、app bootstrap、pubspec.yaml/lock(flame_barrage adapt+依赖并集)、tool/probes(小冲突各自保留对方合理改动)逐文件处理。

## regression_plan

- 合并提交前:全部冲突清零(`git diff --name-only --diff-filter=U` 为空)。
- 批次完成定义(与上轮 276fae8a 同标准):`dart format` 改动 Dart 文件 → `flutter analyze` 零新增 → 全量测试(`flutter test`)全绿 → `python tool/audit_repository.py` 0 error → `git diff --check` 干净 → `python tool/validate_architecture.py --strict` 通过(必要时登记 fork 增量)。
- 运行时:opt-in 探针复验(全站播放/分类/对齐)在合并提交后择窗口跑一轮;真机 Windows 起播抽验(douyu/missevan/17live 直达)验证迭代31 头部转发与上游新链共存。
- 任何一步失败回滚该合并提交,保持 fork master 线性可追溯。

## verification_plan

1. 门禁复核:脚本带 `-AuditDocument docs/UPSTREAM_AUDIT_b087ee90.md -ApproveHighRisk` 复跑,JSON 确认 `audit_document_valid=true`、`violations=[]`(diff_check 尾随空格按先例记录放行,合并后 fork 侧格式化)。
2. 真实合并(`git merge --no-ff`,保留上游祖先关系),冲突按上节分类解决。
3. 依赖:克隆上游 flame_barrage 至 `F:/flame_barrage`(含 retractWhere),pubspec 指向;`pub get` 成功。
4. 静态:format 改动文件;analyze 零新增;validate_architecture;audit_repository。
5. 确定性回归:全量 `flutter test`(合并前基线 149 用例,合并后含上游新增测试)。
6. 台账入账(todo.md 迭代32)+提交推送,核对远端头。

## 附表A:入站提交全量清单(127)

- `f4a5f7b6c8e397591fb945781ab6a75f2b5721ad` refactor(domains): 建 domains 层 —— 34 个站点适配器进 domains/live/data/platforms
- `5e74893f9f3eadc0bad1cf723881f2a1f7e003eb` refactor(architecture): 落地分层架构 —— App/Core/Domains/Features
- `77895fa701e5958b5d2569728e3956307f1a072d` refactor(architecture): core 设置门面去掉业务依赖 —— Cookie 存储与 IPTV 设置归位
- `c6a14115fc7d01a223d03a7f03296e44af1fb2be` refactor(architecture): core 去掉业务 UI 与实现依赖 —— 改走 Core 端口
- `6244a758dda928d5b8ca5641cbf4ee03e787248e` refactor(architecture): core 去掉 App 与跨层实现依赖 —— 启动交接/退出/快照改走端口
- `7c2cdf280a028310315a5d5960aab47f69f9b32f` refactor(architecture): 播放输入类型与官方分类判定归位 —— core 反向依赖 61 -> 58
- `d154377d5abbd6ee7082f92099843fcdc34da5fe` refactor(architecture): 直播平台契约下沉 Core —— 跨域反向依赖 58 -> 49
- `48b84ad41b716664984f524afb732317d60b04fa` refactor(architecture): FFmpeg FLV 中继与上游代理回调归 Core —— 跨域 49 -> 47
- `b7089bdf05f92e44caf0726840eac43c9adc829e` refactor(architecture): 错域文件归位 —— DouyuUtils 与 IPTV 适配器 —— 跨域 47 -> 40
- `bb56c5a61b336a2d43f084d034a70ac5127c1b57` refactor(architecture): 录制按钮归 recorder 域 —— 跨域 40 -> 38
- `20817480dd66257766416a3970bc161f25ad16a4` chore(architecture): 校验脚本成为 CI 门禁 —— 登记 38 处既有耦合，卡住新增
- `3ac0012d845897994b5590a0f4514c9a9ae67eb9` refactor(architecture): 新建 shared 共享层 —— 站点适配器与平台契约上移 —— 跨域 38 -> 21
- `e1475e9aa4ee7b4db9f840ba40298246684d9147` chore(architecture): 门禁拒绝陈旧基线，并更新过时的目录图 —— ledger 38 -> 21
- `b247e631b2dac54ce8d978f0e1754405f46a1b6c` fix(architecture): Niconico master 读取器改为调用时解析 —— 消除初始化顺序依赖
- `07bd2a5c10702a56c4656aa8c50276bd8e9dd006` refactor(platforms): 弹幕相关方法回到站点自己 —— 站点自包含（弹幕切片）
- `56a379b0dfab343d78267a28e5729a31a874657c` refactor(platforms): 官方房间链接回到站点自己 —— 站点自包含（外部打开切片）
- `7285eb625079efdc7f3a1d599db91ed689d664bc` fix(floating): 悬浮小窗的关闭按钮停掉播放 —— 恢复被重构丢掉的收尾
- `d8b8719f349234199634940b4a03238fa3996025` feat(theme): 内置 MI Sans 设为全局默认字体
- `9a845e69d11b7fadb8d3ee6c897d70a5c360cc11` feat(pip): Windows 小窗可解锁比例 —— 高度/宽度可单独调整
- `e96878ae39935e469e11082d7c7344800ae4973b` feat(pip): 小窗最小尺寸可调 + 进入小窗时记录实际生效策略
- `2ee3ee8fd6127059b1be069996b59c2bfea0aded` fix(danmaku): 小窗弹幕比例只做缩小，且设置真正生效
- `873344eb5bf82a977619f07bf294843807b61af8` fix(danmaku): 小窗/画中画弹幕补上「距离顶部/底部」内缩
- `a4eeb7adbe88babc625a75c7540eee009e687099` fix(danmaku): 竖屏弹幕策略与其余遗漏项补到小窗/多画面
- `234df47a46e4a5f019e9c2fc668d48d8775c162d` fix(fullscreen): 全屏进出交给内核呈现链 —— 从全屏进入画中画不再保留全屏状态
- `dc7298500b0c16e05c52e11ee931277598bd8f0e` feat(pip): 小窗几何按横竖屏各记一套 —— 恢复被合并丢掉的竖屏几何
- `753bbbb7e116492af08ea2cfebd629333b368fed` fix(multiview): 多画面有声无画与没有弹幕
- `e437b5bd830388b246d5093cf47852862be03ffd` feat(floating): 应用内悬浮窗记住位置与尺寸（横竖屏各一套）
- `03957c271d128ea52d985e32f9f3d62289273c13` fix(player): 源提交代次从未递增 —— 切换清晰度/线路的界面永不停留
- `fc637dd53e62bc5403dbf1da7a15c73df3582d6e` fix(play_other): 换台面板回到大卡布局 —— 封面固定 16:9，放不下就滚动
- `db5594b990e0a2233c7a2c7ddb9e5a5a23975852` fix(wallpaper): 墙纸网格在 Obx 内读取响应式值 —— 修复背景设置页 ObxError
- `555ed5d3d4a806fadcc404c3b5d80206e1a6ba0e` fix(play_other): 换台面板恢复双形态 —— 窄面板一行一个主播，宽面板才是封面卡片
- `5d29713b8bc539b28de74bdbcf4363d7e2fa0268` feat(wallpaper): 随机图源数据层 —— 源表、随机取图与字节入库
- `813123a65446a3d2fc332fbef79d150dab486680` feat(wallpaper): 背景设置改为分入口 + 自动续页的网格 + 全屏预览
- `b2bafe23a3305a123e86bdab83103d6779231082` docs: 记录背景设置随机图源迁移与分页/预览重构
- `26ca835b4b17f7e279128e5d762ce3f23981a153` fix(theme): 全局主题查找不再在重建空窗里崩 —— 标题栏与 AppTextStyles
- `8e52f167f8588c6218b47df73547bcec3981d788` fix(wallpaper): 背景层不再在有无壁纸之间换树形 —— 导航子树不整棵失活
- `907a34d353c62ca657523a7b264d6b9f304b9744` feat(bilibili): 摘取 4.x 的轮播房支持与心跳人气修正
- `489aaf85949bae4e98a2aed93e965584d930f09f` feat(douyu): 摘取 4.x 的下播结束弹幕与分区图标兜底
- `ac69fc2c113399e49b1c58a4e8c332f4841b8f2e` fix(huya): 搜索与分组树补上 User-Agent —— 否则 403 Not allowed
- `b1d10539261984c5f0dbb219c339f72d2e889e30` feat(wallpaper): 分页改用应用统一分页条，预览页控件改为弹窗，子页透明
- `50fe8ffe913131ce83183b67d7306c0d276a0955` feat(douyin): 摘取 4.x 的直播判定兜底、游戏分区、精确在线人数与聊天时间
- `5a13f924b24106de050232f205901731830fc059` feat(kuaishou): 摘取 4.x 的 H.265 独有档位与详情标题兜底
- `654acc89e5c5722ec23bd769ae02f80e15bf3e8e` feat(core): 摘取 4.x 的不可见占位字符清理 —— 房间文本与弹幕文本
- `694b16d139b5b7578fff18c93fb34c20b7efc7b0` feat(live): 平台选择器统一带平台 logo —— 关注 / 热门 / 搜索 与分区一致
- `08db50b3b2e1ca310dc9c0a0a763f0e41a628d30` feat(yy): 摘取 4.x 的分区名预置、默认标题去后缀与弹幕热度
- `d8d47d058487188f135246cd1061c290eaa7ffa0` fix(cc): 摘取 4.x 的「【重播】」判定与推荐卡分区字段
- `8d3564ce51e92f047d9d906d03a98f9d09bf0bd7` feat(live): 站点分类平铺按站点表决定 —— 同步 TV 的 area_display_config
- `2f57b28d9336d4332f28a92990ab100562c15600` feat(twitch): 摘取 4.x 的图片直连、媒体不带登录 Cookie 与详情字段
- `b3e26747da66df6f1e597c95e519b296684207d9` feat(soop): 摘取 4.x 的 HTML 实体解码与搜索分区字段
- `cba9fbd3a25f3c8b50f94a31750c5496207ad815` feat(chzzk): 摘取 4.x 的频道链接、搜索页长/关键词与未开播判定
- `dd1fa503485c061961e15b860fadaa892026ffdd` fix(wallpaper): 背景只在背景页可见 —— 页面透明改在树上生效，贯穿整个 App
- `1c3f4500167f2c1e0062dad41307c8fc274007e2` feat(kugoulive): 摘取 4.x 的播放限制根因、卡片状态与标题/公告
- `17fb0611b8a3ddab023a7f679ee9b50efb675ccf` ﻿fix(wallpaper): 进入页面闪一下 —— 过渡期的 surface 底衬在壁纸下改为透明
- `3c3322df16a8eea44e18731764fee640db9f6299` feat(pandalive): 摘取 4.x 的 IVS 线路租约与录播重播判定
- `0c84c3471c376b5fb06313d0be5a10f2a8f9acc8` ﻿feat(live): 播放页背景跟随壁纸 —— 窗口态让出 canvas，全屏/小窗保持黑底
- `7c1b9c0a45d0bebf7cf1ee3f44e392054127f2f8` feat(picarto): 摘取 4.x 的搜索卡片简介字段
- `04bbda9dc6474469b8a216c921805bd736e67bd7` docs(ledger): niconico 评估结论（房间即主播模型与 NDGR 评论，留待后续批次）
- `a3a0d2dfaa9e58b9ab72f872d876ddfa9427ba3c` feat(missevan,kilakila): 摘取 4.x 的单档线路回退与下播判定
- `5e26c6933c6080439535fb4a541f42980c74e094` feat(weibo,steambroadcast): 摘取 4.x 的快照状态与头像规则
- `531bcae87da2b2f212c758f3b22694d5b9ec90c1` feat(liveme,showroom,fc2live): 摘取 4.x 的未开播状态与观众数口径
- `3e5a99b7de194e66716c446136acb1ca177ff388` feat(bigo,sixroom): 摘取 4.x 的封面截图与搜索卡片状态
- `df2b67b710ec3a0357d1ac440dfcb7854d9060d9` feat(seventeenlive,acfun): 摘取 4.x 的链接主机/搜索关键词与「全部」分区
- `286661099d5cbd89fcd0515f1627e04b704f66db` feat(baidulive,twitcasting): 摘取 4.x 的 http 播放主机与直播 telop 标题
- `a02bcba840a1eea18b2be8ebc900e39491b3711d` feat(jdlive,looklive,inke): 摘取 4.x 的封禁状态、占位名清理与封面来源
- `f54d11d532d80b597eadc7231297719c1454f5aa` feat(xiaohongshu): 摘取 4.x 的房间不存在判定与 App 深链参数
- `0152eb04be7c65d212a4af4d39133a6a41f0cd1e` feat(tiktok): 摘取 4.x 的短链搜索与容错解析
- `a7783b525a401bd8afe2a490713462a7eb8bbfc8` feat(backup,danmaku,player): 备份模块勾选、弹幕海量模式与播放器内核整理
- `15c72a90991a5a646b6545912cfbda885b767200` feat(model,tiktok): 补 startedAt/restriction 模型与 TikTok 受限直播口径
- `54b4d92d88822ba953abc11efefc4cf06066ed03` feat(wallpaper): 壁纸延伸到标题栏与左侧导航栏 —— 顶部/左边也铺满
- `35bfc0746d06bdd48c89a9117b5b4eae603433ec` fix(liveme): 摘取 21-5/21-8 受限直播口径与开播时间
- `71e33de5a31afdcccc060e6ab5997d1f8feca5ba` fix(fc2live): 摘取 26-9 受限直播的限制种类与开播时间
- `f9b97fa5a48ef2f3737f6224ee9c35c36c39c953` fix(bigo,jdlive): 摘取受限直播的限制种类（24-2 / appOnly）
- `f641c8514e3c3e86d19dd4f880428ef11d96723d` feat(wallpaper): 卡片/分页条/顶栏等组件底色跟随壁纸 —— 不再是一块白
- `23af1c8fc29806387f041a9d97b77d62a5c8e44a` fix(weibo,showroom,kuaishou): 摘取受限直播状态与限制种类（18-4 / 19-x / unplayable）
- `bf606692f9c6278ebe335d0a0bc7d9e5ee64f5f3` fix(wallpaper): 弹窗/下拉菜单不再透出壁纸 —— 只洗页面 chrome
- `03269a431ad8c29493480bf7f4f43e4a3ddec238` fix(picarto,twitcasting): 摘取私密/密码/不可播的限制种类
- `937f31da90fb4f7b04ec009043d9e9027f413b85` fix(seventeenlive): 摘取 premiumContent 锁定的限制种类
- `4db5394477ce469a5e5d812cc472781faa1eca96` fix(steambroadcast): 摘取 missing_subscription 与 is_replay 的状态/限制
- `185ff91a0629e77e8539f9c3a5ae85c6b851fad6` fix(sixroom): 摘取私密/黑屏房间的限制种类
- `0a3749d373d95c91e1bd8876caf8feb2e20d7e3f` docs(ledger): 记录范围决定——不新写弹幕引擎，只同步站点侧弹幕显示
- `2a3a713a5d666e4ac8e42789890ae0f561733726` fix(wallpaper): 页面切换不再闪白/闪黑 —— 改用淡出后再淡入的过渡
- `469e9926a03a5884e62407c4df774d05d5b6dcb5` fix(acfun): 摘取付费节目的限制种类
- `463edd38aded1f1f99c332df1202d2205fda22b6` fix(baidulive): 摘取付费/禁止/封禁的限制种类
- `7f7b5d2888d591abe45ba24b4a3e8337332f85a6` fix(wallpaper): 卡片改深、两页观感一致 —— 加一个卡片专用透明度
- `bbc0ef44c5d9c972f03d4e68ca018d28c71dc978` feat(cc): 摘取开播时间与"有档位即无限制"
- `4cb814033208cf458e445dd0f2fca398b0e19fe0` feat(seventeenlive): 摘取 33-7 的开播时间
- `ec327f40624ba6a1eabe3ff5ce98d547e7d9f980` feat(twitch): 摘取开播时间
- `183cd2ab633fb562a951d6ecd07a9e0bcecdc738` feat(acfun): 摘取 10-3 的开播时间
- `0524c901f7708f9556ce6c23040ac1e357c275b4` fix(wallpaper): 没设壁纸时背景设置各页底色不同 —— 去掉写死的透明 Scaffold
- `5d187d7cafb79fe6ea0cc622022d1b68df9a26f2` feat(douyu): 摘取开播时间
- `c23cff07e5ecea2f992ff58158e5618b35cd6eda` feat(douyin): 摘取开播时间
- `f7c61d4f0016eb0249fb88dae1fbe487b06f37b7` refactor: 调整导入顺序以提高代码可读性
- `ffd53aeec72cf6eb9116d8474b49b16c60e9292a` feat(showroom): 摘取 current_live_started_at 开播时间
- `adcfd0c0633aea3b01899dfbb32487b5916feb16` feat(inke): 摘取 start_time 开播时间
- `02fd06363e159a506511907cc1654c245c592924` feat(huya): 摘取搜索卡片的付费标记
- `7e90a15e71ebf85279ccc9f48a276c284c773072` fix(favorite): 刷新失败的日志只报"哪个直播间" —— 不再每个房间一串堆栈
- `7f31d7756058d9860d8abb597cb7614ec6527a68` feat(bilibili): 摘取付费房限制
- `0217414904edb325a4e1bb093137fcee8ea78750` feat(bilibili): 摘取详情开播时间
- `41ec1fcb32ac9cf03847aae1c213012aa30411bf` polish(favorite): 失败条目合并成一组括号 —— `小明（douyin/123456，TimeoutException）`
- `b0afe3a554e52f81e595697be84c29414906b777` docs(ledger): B 站弹幕公告已有回执；撤回属跨层改动并记录原因
- `fcdbd588544839c460db1bc4fbfef7113699246f` fix(danmaku): 打码昵称不再参与屏蔽匹配
- `6e5b10da942f4a92fa78490f42d364f5a455ee5d` docs(ledger): 记录 84b9fe205 不适用（本仓无该运行时，快手轮询已是单定时器）
- `dcfe7aeb201df7c690196b2e3857e514d6dfd954` docs(ledger): 批次2 核查表——8 个已有引擎站点的弹幕改动分类
- `497e20c80287825902d846479f9846ee56f8e3ac` docs(ledger): 快手表情图片需跨层（LiveMessage.emotes），修正批次2 分类
- `89248f0ff16d5f085f3cbb5210e2e112e8c47e71` feat(model): 新增 LiveMessageType.retraction 与 LiveRetraction（弹幕撤回的公共模型）
- `0533df81b51cc003cd5733efa8735c595a8f9103` feat(bilibili): 解析弹幕撤回（RECALL_DANMU_MSG / 醒目留言删除）
- `db09fc212ea67fd39750b4d60f92f8826a66271a` feat(danmaku): 撤回接入显示层，打通整条链路
- `4966ca1ce51b6909d71a44b21d5f4c0c0b9e18da` feat(danmaku): 撤回打通到画面弹幕（引擎侧新增按条撤回）
- `11a47144e6ef338212fe8c8aa278944fac6ef93a` feat(danmaku): 平台礼物进弹幕列表展示（B 站 SEND_GIFT/COMBO_SEND/GUARD_BUY）
- `43540cc106be34a952b4afcfdb0af2243a1b291e` feat(model): LiveMessage.emotes 与 LiveEmote（消息里的表情图片）
- `9fb1ef1da11aa850f53c3e1dca057240d8c2d9a4` feat(bilibili): 解析聊天里的贴纸与内联表情
- `c4699764d7b7878190462190bfc22fd30aaf8c73` feat(danmaku): 弹幕列表渲染消息自带的表情图片
- `f587c26a30f9e9428c9129b4f554ea777c8a59cb` feat(danmaku): 画面弹幕渲染消息自带的表情图片
- `c217b86bcf005e65d0bd12479a1e6c471d02eaff` feat(kuaishou): 弹幕参数带表情表，评论里的编码填进 emotes
- `dffed3f692cacd0eea939ea2f34907c4a87cd496` feat(kuaishou): 从房间页取表情表并挂进弹幕参数
- `6e79b8bda95202e3deafeeca32f4665b91a45328` feat(danmaku): 平台公告进弹幕列表（B 站 WARNING / CUT_OFF）
- `133725ed71ee7b3519f2da3d88572a37d41f5321` fix(huya): 结束直播通知结束这一路弹幕（C-10）
- `07a91cd11667a74f674c1b911307a11482160c78` docs(ledger): B 站轮播 play_time 起播偏移的实施方案（三层五步）
- `4291990b6ba5824196f04270a24714cbb076bbc5` feat(bilibili): 轮播起播位置从站点解析到播放层（第 1-3 步）
- `425d94aebe44875ebaff1f66c81e7c97fab6c794` docs(ledger): 轮播起播偏移第 4-5 步的障碍——本仓播放层没有暴露 seek
- `631ca6e221c94b30efac5bcfa6b9e68432fd2191` docs(ledger): ③ 身份模型的实测现状与实施方案
- `764c25c571de5001f285719d6154084adfb643d2` docs(ledger): ③ 复评——YouTube 功能已等价，建议只做 niconico
- `abb4c726981cb7d8948f1ee60e90c9fbda94f13a` feat(niconico): 摘取 17-2 的节目链接形态（http / sp.live / nico.ms）
- `bb1f6fbae2d45e09bbcd0f0ed0adc096d2c4dd0d` feat(niconico): 主播链接可打开（房间身份仍是节目号）
- `c0477ed6c1b25ead2e75ce198e69f9a56187d7eb` docs(ledger): ③ niconico 的剩余部分就是身份翻转本身（无中间态）
- `e38021e6eaee46d2a41a4bec8f1048228ba26169` docs(ledger): 同步状态总览（收尾核对）
- `b087ee901eb35b568ec91bcedd2c259428f4c6f3` chore: update releases.json [skip ci]

## 附表B:入站文件全量清单(621,全部逐字在案)


### .github/workflows/ (1)

- [新增] `.github/workflows/architecture.yml`

### AGENTS.md/ (1)

- [修改] `AGENTS.md`

### assets/fonts/ (1)

- [新增] `assets/fonts/MiSans-Regular.ttf`

### assets/releases.json/ (1)

- [修改] `assets/releases.json`

### assets/translations/ (2)

- [修改] `assets/translations/en.json`
- [修改] `assets/translations/zh.json`

### docs/PLATFORM_SYNC_LEDGER_4X.md/ (1)

- [新增] `docs/PLATFORM_SYNC_LEDGER_4X.md`

### docs/WALLPAPER_SOURCES_PAGING_PREVIEW_2026_10_03.md/ (1)

- [新增] `docs/WALLPAPER_SOURCES_PAGING_PREVIEW_2026_10_03.md`

### lib/app/ (6)

- [修改] `lib/app/bootstrap/desktop_exit_flow.dart`
- [修改] `lib/app/bootstrap/initial_services.dart`
- [修改] `lib/app/bootstrap/initialized.dart`
- [修改] `lib/app/router/app_pages.dart`
- [修改] `lib/app/router/navigation_observer.dart`
- [修改] `lib/app/router/page_bindings.dart`

### lib/core/ (92)

- [更名] `lib/services/settings/app_settings_controller.dart` → `lib/core/config/app_settings_controller.dart`
- [更名] `lib/services/settings/cache_controller.dart` → `lib/core/config/cache_controller.dart`
- [更名] `lib/services/settings/cookie_settings_controller.dart` → `lib/core/config/cookie_settings_controller.dart`
- [更名] `lib/services/settings/danmaku_settings_controller.dart` → `lib/core/config/danmaku_settings_controller.dart`
- [更名] `lib/services/display_mode_service.dart` → `lib/core/config/display_mode_service.dart`
- [更名] `lib/services/settings/exit_settings_controller.dart` → `lib/core/config/exit_settings_controller.dart`
- [新增] `lib/core/config/float_window_geometry.dart`
- [更名] `lib/services/settings/font_settings_controller.dart` → `lib/core/config/font_settings_controller.dart`
- [新增] `lib/core/config/index.dart`
- [更名] `lib/services/settings/log_controller.dart` → `lib/core/config/log_controller.dart`
- [更名] `lib/services/migration/backup_migration_util.dart` → `lib/core/config/migrations/backup_migration_util.dart`
- [更名] `lib/services/migration/settings_upgrade_migration.dart` → `lib/core/config/migrations/settings_upgrade_migration.dart`
- [更名] `lib/services/settings/page_settings_controller.dart` → `lib/core/config/page_settings_controller.dart`
- [更名] `lib/services/settings/player_settings_controller.dart` → `lib/core/config/player_settings_controller.dart`
- [更名] `lib/services/settings/proxy_settings_controller.dart` → `lib/core/config/proxy_settings_controller.dart`
- [更名] `lib/services/settings/refresh_config_controller.dart` → `lib/core/config/refresh_config_controller.dart`
- [更名] `lib/services/settings/room_card_settings_controller.dart` → `lib/core/config/room_card_settings_controller.dart`
- [新增] `lib/core/config/settings_service.dart`
- [更名] `lib/services/settings/startup_controller.dart` → `lib/core/config/startup_controller.dart`
- [更名] `lib/services/settings/theme_settings_controller.dart` → `lib/core/config/theme_settings_controller.dart`
- [更名] `lib/services/settings/volume_settings_controller.dart` → `lib/core/config/volume_settings_controller.dart`
- [更名] `lib/services/settings/window_size_controller.dart` → `lib/core/config/window_size_controller.dart`
- [修改] `lib/core/consts/app_consts.dart`
- [新增] `lib/core/consts/platform_ids.dart`
- [删除] `lib/core/emoji/unified_emoji_model.dart`
- [修改] `lib/core/index.dart`
- [修改] `lib/core/logging/app_log.dart`
- [修改] `lib/core/logging/core_log.dart`
- [修改] `lib/core/models/live_message.dart`
- [修改] `lib/core/models/live_room.dart`
- [更名] `lib/app/router/app_navigation.dart` → `lib/core/navigation/app_navigator.dart`
- [新增] `lib/core/navigation/current_route.dart`
- [新增] `lib/core/navigation/official_category_policy.dart`
- [更名] `lib/app/router/route_path.dart` → `lib/core/navigation/route_path.dart`
- [更名] `lib/services/settings/cookie_sanitizer.dart` → `lib/core/network/cookie_sanitizer.dart`
- [更名] `lib/platforms/douyu/douyu_utils.dart` → `lib/core/network/douyu_utils.dart`
- [修改] `lib/core/network/http_client.dart`
- [修改] `lib/core/network/webview_proxy_scope.dart`
- [新增] `lib/core/platform/desktop_exit_port.dart`
- [修改] `lib/core/platform/desktop_manager.dart`
- [修改] `lib/core/platform/font_download_manager.dart`
- [新增] `lib/core/platform/initial_room_handoff.dart`
- [新增] `lib/core/platform/multi_instance_settings_source.dart`
- [修改] `lib/core/platform/windows_multi_instance_launcher.dart`
- [更名] `lib/player/core/background_playback_policy.dart` → `lib/core/player/core/background_playback_policy.dart`
- [更名] `lib/player/core/background_playback_service.dart` → `lib/core/player/core/background_playback_service.dart`
- [更名] `lib/player/core/live_audio_service.dart` → `lib/core/player/core/live_audio_service.dart`
- [更名] `lib/player/core/live_message_normalization.dart` → `lib/core/player/core/live_message_normalization.dart`
- [更名] `lib/player/core/live_room_volume_manager.dart` → `lib/core/player/core/live_room_volume_manager.dart`
- [更名] `lib/player/core/media_kit_player_accessor.dart` → `lib/core/player/core/media_kit_player_accessor.dart`
- [新增] `lib/core/player/core/playback_input_lease.dart`
- [更名] `lib/player/core/playback_lifecycle_coordinator.dart` → `lib/core/player/core/playback_lifecycle_coordinator.dart`
- [更名] `lib/player/core/playback_proxy_policy.dart` → `lib/core/player/core/playback_proxy_policy.dart`
- [更名] `lib/player/core/playback_source.dart` → `lib/core/player/core/playback_source.dart`
- [更名] `lib/player/core/portrait_stream_support.dart` → `lib/core/player/core/portrait_stream_support.dart`
- [更名] `lib/player/kernel/floating_playback.dart` → `lib/core/player/kernel/floating_playback.dart`
- [更名] `lib/player/kernel/media_kit_live_properties.dart` → `lib/core/player/kernel/media_kit_live_properties.dart`
- [更名] `lib/player/kernel/mpv_option_labels.dart` → `lib/core/player/kernel/mpv_option_labels.dart`
- [更名] `lib/player/kernel/mpv_platform_profile.dart` → `lib/core/player/kernel/mpv_platform_profile.dart`
- [更名] `lib/player/kernel/owned_input_opener.dart` → `lib/core/player/kernel/owned_input_opener.dart`
- [更名] `lib/player/kernel/player_consts.dart` → `lib/core/player/kernel/player_consts.dart`
- [更名] `lib/player/kernel/player_kernel_service.dart` → `lib/core/player/kernel/player_kernel_service.dart`
- [更名] `lib/player/kernel/player_preset.dart` → `lib/core/player/kernel/player_preset.dart`
- [更名] `lib/player/models/player_engine.dart` → `lib/core/player/models/player_engine.dart`
- [更名] `lib/player/presentation/active_video_content_analyzer.dart` → `lib/core/player/presentation/active_video_content_analyzer.dart`
- [新增] `lib/core/player/presentation/compact_source_orientation.dart`
- [更名] `lib/player/presentation/fullscreen_window.dart` → `lib/core/player/presentation/fullscreen_window.dart`
- [更名] `lib/player/presentation/media_kit_content_probe.dart` → `lib/core/player/presentation/media_kit_content_probe.dart`
- [更名] `lib/player/presentation/pip_window_widget.dart` → `lib/core/player/presentation/pip_window_widget.dart`
- [更名] `lib/player/presentation/popup_route_tracker.dart` → `lib/core/player/presentation/popup_route_tracker.dart`
- [更名] `lib/player/presentation/video_output_size_policy.dart` → `lib/core/player/presentation/video_output_size_policy.dart`
- [更名] `lib/player/presentation/windows_pip_driver.dart` → `lib/core/player/presentation/windows_pip_driver.dart`
- [更名] `lib/player/super_resolution.dart` → `lib/core/player/super_resolution.dart`
- [新增] `lib/core/release/release_history_source.dart`
- [修改] `lib/core/release/version_util.dart`
- [更名] `lib/features/recorder/services/ffmpeg_flv_input_relay.dart` → `lib/core/stream/ffmpeg_flv_input_relay.dart`
- [新增] `lib/core/stream/upstream_proxy_routing.dart`
- [新增] `lib/core/theme/app_canvas_scope.dart`
- [修改] `lib/core/theme/app_text_styles.dart`
- [修改] `lib/core/theme/index.dart`
- [修改] `lib/core/theme/theme.dart`
- [更名] `lib/features/toolbox/toolbox_action_scope.dart` → `lib/core/utils/action_scope.dart`
- [新增] `lib/core/utils/invisible_placeholders.dart`
- [修改] `lib/core/utils/text_util.dart`
- [修改] `lib/core/widgets/adaptive_refresh_rate_scope.dart`
- [修改] `lib/core/widgets/app_status_view.dart`
- [修改] `lib/core/widgets/common_appbar_actions.dart`
- [修改] `lib/core/widgets/common_avatar.dart`
- [修改] `lib/core/widgets/download_apk_dialog.dart`
- [修改] `lib/core/widgets/index.dart`
- [修改] `lib/core/widgets/menu_button.dart`
- [修改] `lib/core/widgets/widget_extensions.dart`

### lib/domains/ (263)

- [更名] `lib/services/account/bilibili_account_service.dart` → `lib/domains/account/data/bilibili_account_service.dart`
- [更名] `lib/features/account/account_controller.dart` → `lib/domains/account/presentation/account/account_controller.dart`
- [更名] `lib/features/account/account_cookie_editor.dart` → `lib/domains/account/presentation/account/account_cookie_editor.dart`
- [更名] `lib/features/account/account_page.dart` → `lib/domains/account/presentation/account/account_page.dart`
- [更名] `lib/features/account/bilibili/bilibili_bindings.dart` → `lib/domains/account/presentation/account/bilibili/bilibili_bindings.dart`
- [更名] `lib/features/account/bilibili/bilibili_login_qr_code.dart` → `lib/domains/account/presentation/account/bilibili/bilibili_login_qr_code.dart`
- [更名] `lib/features/account/bilibili/qr_login_controller.dart` → `lib/domains/account/presentation/account/bilibili/qr_login_controller.dart`
- [更名] `lib/features/account/bilibili/qr_login_page.dart` → `lib/domains/account/presentation/account/bilibili/qr_login_page.dart`
- [更名] `lib/features/account/bilibili/web_login_controller.dart` → `lib/domains/account/presentation/account/bilibili/web_login_controller.dart`
- [更名] `lib/features/account/bilibili/web_login_page.dart` → `lib/domains/account/presentation/account/bilibili/web_login_page.dart`
- [更名] `lib/features/account/douyin/douyin_cookie_controller.dart` → `lib/domains/account/presentation/account/douyin/douyin_cookie_controller.dart`
- [更名] `lib/features/account/douyin/douyin_cookie_page.dart` → `lib/domains/account/presentation/account/douyin/douyin_cookie_page.dart`
- [更名] `lib/features/account/douyu/douyu_cookie_controller.dart` → `lib/domains/account/presentation/account/douyu/douyu_cookie_controller.dart`
- [更名] `lib/features/account/douyu/douyu_cookie_page.dart` → `lib/domains/account/presentation/account/douyu/douyu_cookie_page.dart`
- [更名] `lib/features/account/huya/huya_cookie_controller.dart` → `lib/domains/account/presentation/account/huya/huya_cookie_controller.dart`
- [更名] `lib/features/account/huya/huya_cookie_page.dart` → `lib/domains/account/presentation/account/huya/huya_cookie_page.dart`
- [更名] `lib/features/account/kuaishou/kuaishou_cookie_controller.dart` → `lib/domains/account/presentation/account/kuaishou/kuaishou_cookie_controller.dart`
- [更名] `lib/features/account/kuaishou/kuaishou_cookie_page.dart` → `lib/domains/account/presentation/account/kuaishou/kuaishou_cookie_page.dart`
- [更名] `lib/features/account/soop/soop_cookie_controller.dart` → `lib/domains/account/presentation/account/soop/soop_cookie_controller.dart`
- [更名] `lib/features/account/soop/soop_cookie_page.dart` → `lib/domains/account/presentation/account/soop/soop_cookie_page.dart`
- [更名] `lib/features/account/twitch/twitch_cookie_controller.dart` → `lib/domains/account/presentation/account/twitch/twitch_cookie_controller.dart`
- [更名] `lib/features/account/twitch/twitch_cookie_page.dart` → `lib/domains/account/presentation/account/twitch/twitch_cookie_page.dart`
- [更名] `lib/features/account/yy/yy_cookie_controller.dart` → `lib/domains/account/presentation/account/yy/yy_cookie_controller.dart`
- [更名] `lib/features/account/yy/yy_cookie_page.dart` → `lib/domains/account/presentation/account/yy/yy_cookie_page.dart`
- [更名] `lib/features/auth/auth_controller.dart` → `lib/domains/account/presentation/auth/auth_controller.dart`
- [更名] `lib/features/auth/components/firebase_email_auth.dart` → `lib/domains/account/presentation/auth/components/firebase_email_auth.dart`
- [更名] `lib/features/auth/components/user_detail_main_page.dart` → `lib/domains/account/presentation/auth/components/user_detail_main_page.dart`
- [更名] `lib/features/auth/mine_page.dart` → `lib/domains/account/presentation/auth/mine_page.dart`
- [更名] `lib/features/auth/models/policy_model.dart` → `lib/domains/account/presentation/auth/models/policy_model.dart`
- [更名] `lib/features/auth/models/user_config_model.dart` → `lib/domains/account/presentation/auth/models/user_config_model.dart`
- [更名] `lib/features/auth/models/user_item.dart` → `lib/domains/account/presentation/auth/models/user_item.dart`
- [更名] `lib/features/auth/sign_in_page.dart` → `lib/domains/account/presentation/auth/sign_in_page.dart`
- [更名] `lib/features/auth/user_manage_page.dart` → `lib/domains/account/presentation/auth/user_manage_page.dart`
- [更名] `lib/features/auth/user_management_actions.dart` → `lib/domains/account/presentation/auth/user_management_actions.dart`
- [更名] `lib/features/auth/user_server_remote_controller.dart` → `lib/domains/account/presentation/auth/user_server_remote_controller.dart`
- [更名] `lib/features/auth/utils/constants.dart` → `lib/domains/account/presentation/auth/utils/constants.dart`
- [更名] `lib/features/auth/utils/firebase_manager.dart` → `lib/domains/account/presentation/auth/utils/firebase_manager.dart`
- [更名] `lib/core/iptv/iptv_repository.dart` → `lib/domains/iptv/data/iptv_repository.dart`
- [更名] `lib/services/settings/iptv_settings_controller.dart` → `lib/domains/iptv/data/iptv_settings_controller.dart`
- [更名] `lib/core/iptv/local/database.dart` → `lib/domains/iptv/data/local/database.dart`
- [更名] `lib/core/iptv/local/database.g.dart` → `lib/domains/iptv/data/local/database.g.dart`
- [更名] `lib/core/iptv/local/db_service.dart` → `lib/domains/iptv/data/local/db_service.dart`
- [更名] `lib/core/iptv/local/tables.dart` → `lib/domains/iptv/data/local/tables.dart`
- [更名] `lib/core/iptv/parsers/json_epg_parser.dart` → `lib/domains/iptv/data/parsers/json_epg_parser.dart`
- [更名] `lib/core/iptv/parsers/m3u_parser.dart` → `lib/domains/iptv/data/parsers/m3u_parser.dart`
- [更名] `lib/core/iptv/parsers/txt_parser.dart` → `lib/domains/iptv/data/parsers/txt_parser.dart`
- [更名] `lib/core/iptv/parsers/xmltv_parser.dart` → `lib/domains/iptv/data/parsers/xmltv_parser.dart`
- [新增] `lib/domains/iptv/data/platforms/iptv_danmaku_capability.dart`
- [更名] `lib/platforms/iptv/iptv_site.dart` → `lib/domains/iptv/data/platforms/iptv_site.dart`
- [更名] `lib/core/iptv/playlist_storage.dart` → `lib/domains/iptv/data/playlist_storage.dart`
- [更名] `lib/core/iptv/provider.dart` → `lib/domains/iptv/data/provider.dart`
- [更名] `lib/core/iptv/services/auto_sync_scheduler.dart` → `lib/domains/iptv/data/services/auto_sync_scheduler.dart`
- [更名] `lib/core/iptv/services/epg_auto_mapper.dart` → `lib/domains/iptv/data/services/epg_auto_mapper.dart`
- [更名] `lib/core/iptv/services/epg_import_manager.dart` → `lib/domains/iptv/data/services/epg_import_manager.dart`
- [更名] `lib/core/iptv/services/epg_sync_engine.dart` → `lib/domains/iptv/data/services/epg_sync_engine.dart`
- [更名] `lib/core/iptv/services/iptv_import_manager.dart` → `lib/domains/iptv/data/services/iptv_import_manager.dart`
- [更名] `lib/core/iptv/services/iptv_sync_engine.dart` → `lib/domains/iptv/data/services/iptv_sync_engine.dart`
- [更名] `lib/core/iptv/services/playlist_channel_reconciler.dart` → `lib/domains/iptv/data/services/playlist_channel_reconciler.dart`
- [更名] `lib/core/iptv/models/channel.dart` → `lib/domains/iptv/domain/channel.dart`
- [更名] `lib/core/iptv/models/epg.dart` → `lib/domains/iptv/domain/epg.dart`
- [更名] `lib/core/iptv/fuzzy_match.dart` → `lib/domains/iptv/domain/fuzzy_match.dart`
- [更名] `lib/core/iptv/parsers/playlist_parse_result.dart` → `lib/domains/iptv/domain/playlist_parse_result.dart`
- [更名] `lib/core/iptv/models/show.dart` → `lib/domains/iptv/domain/show.dart`
- [更名] `lib/core/iptv/services/channel_detail_controller.dart` → `lib/domains/iptv/presentation/channel_detail_controller.dart`
- [更名] `lib/features/live/iptv/iptv_manage.dart` → `lib/domains/iptv/presentation/iptv_manage.dart`
- [更名] `lib/features/live/iptv/iptv_page.dart` → `lib/domains/iptv/presentation/iptv_page.dart`
- [更名] `lib/features/toolbox/toolbox_direct_link_flow.dart` → `lib/domains/live/data/direct_link_flow.dart`
- [更名] `lib/services/settings/favorite_room_controller.dart` → `lib/domains/live/data/favorite_room_controller.dart`
- [更名] `lib/services/settings/history_controller.dart` → `lib/domains/live/data/history_controller.dart`
- [更名] `lib/core/link/live_url_tool.dart` → `lib/domains/live/data/link/live_url_tool.dart`
- [更名] `lib/core/link/shared_live_link_opener.dart` → `lib/domains/live/data/link/shared_live_link_opener.dart`
- [更名] `lib/features/live/search/web_search_room_parser.dart` → `lib/domains/live/data/link/web_search_room_parser.dart`
- [新增] `lib/domains/live/data/platforms/danmaku_emote_loader.dart`
- [更名] `lib/platforms/sites.dart` → `lib/domains/live/data/platforms/sites.dart`
- [更名] `lib/player/core/playback_header_resolver.dart` → `lib/domains/live/data/playback_header_resolver.dart`
- [更名] `lib/player/core/flv_legacy_hevc_relay.dart` → `lib/domains/live/data/stream/flv_legacy_hevc_relay.dart`
- [更名] `lib/player/core/flv_splice_relay.dart` → `lib/domains/live/data/stream/flv_splice_relay.dart`
- [更名] `lib/player/core/playback_source_transport.dart` → `lib/domains/live/data/stream/playback_source_transport.dart`
- [更名] `lib/player/global_player_service.dart` → `lib/domains/live/domain/global_player_service.dart`
- [更名] `lib/player/core/live_input_playback_binder.dart` → `lib/domains/live/domain/live_input_playback_binder.dart`
- [更名] `lib/player/kernel/live_player_facade.dart` → `lib/domains/live/domain/live_player_facade.dart`
- [更名] `lib/features/live/area_rooms/area_rooms_controller.dart` → `lib/domains/live/presentation/area_rooms/area_rooms_controller.dart`
- [更名] `lib/features/live/area_rooms/area_rooms_page.dart` → `lib/domains/live/presentation/area_rooms/area_rooms_page.dart`
- [更名] `lib/features/live/areas/area_card.dart` → `lib/domains/live/presentation/areas/area_card.dart`
- [新增] `lib/domains/live/presentation/areas/area_display_config.dart`
- [更名] `lib/features/live/areas/area_pic_mapper.dart` → `lib/domains/live/presentation/areas/area_pic_mapper.dart`
- [更名] `lib/features/live/areas/areas_controller.dart` → `lib/domains/live/presentation/areas/areas_controller.dart`
- [更名] `lib/features/live/areas/areas_grid_view.dart` → `lib/domains/live/presentation/areas/areas_grid_view.dart`
- [更名] `lib/features/live/areas/areas_list_controller.dart` → `lib/domains/live/presentation/areas/areas_list_controller.dart`
- [更名] `lib/features/live/areas/areas_page.dart` → `lib/domains/live/presentation/areas/areas_page.dart`
- [更名] `lib/features/live/areas/category_artwork.dart` → `lib/domains/live/presentation/areas/category_artwork.dart`
- [更名] `lib/features/live/areas/favorite_areas_controller.dart` → `lib/domains/live/presentation/areas/favorite_areas_controller.dart`
- [更名] `lib/features/live/areas/favorite_areas_page.dart` → `lib/domains/live/presentation/areas/favorite_areas_page.dart`
- [更名] `lib/features/live/favorite/favorite_controller.dart` → `lib/domains/live/presentation/favorite/favorite_controller.dart`
- [更名] `lib/features/live/favorite/favorite_page.dart` → `lib/domains/live/presentation/favorite/favorite_page.dart`
- [更名] `lib/features/live/favorite/favorite_startup_policy.dart` → `lib/domains/live/presentation/favorite/favorite_startup_policy.dart`
- [更名] `lib/features/live/favorite/room_grid_view.dart` → `lib/domains/live/presentation/favorite/room_grid_view.dart`
- [更名] `lib/features/live/history/history_page.dart` → `lib/domains/live/presentation/history/history_page.dart`
- [更名] `lib/features/live/hot_areas/hot_areas_controller.dart` → `lib/domains/live/presentation/hot_areas/hot_areas_controller.dart`
- [更名] `lib/features/live/hot_areas/hot_areas_page.dart` → `lib/domains/live/presentation/hot_areas/hot_areas_page.dart`
- [更名] `lib/features/live/multiview/danmaku/multiview_danmaku_session.dart` → `lib/domains/live/presentation/multiview/danmaku/multiview_danmaku_session.dart`
- [更名] `lib/features/live/multiview/danmaku/multiview_danmaku_settings_source.dart` → `lib/domains/live/presentation/multiview/danmaku/multiview_danmaku_settings_source.dart`
- [更名] `lib/features/live/multiview/models/multiview_models.dart` → `lib/domains/live/presentation/multiview/models/multiview_models.dart`
- [更名] `lib/features/live/multiview/multiview_controller.dart` → `lib/domains/live/presentation/multiview/multiview_controller.dart`
- [更名] `lib/features/live/multiview/multiview_page.dart` → `lib/domains/live/presentation/multiview/multiview_page.dart`
- [更名] `lib/features/live/multiview/widgets/focus_rail_visibility.dart` → `lib/domains/live/presentation/multiview/widgets/focus_rail_visibility.dart`
- [更名] `lib/features/live/multiview/widgets/multiview_fullscreen_surface.dart` → `lib/domains/live/presentation/multiview/widgets/multiview_fullscreen_surface.dart`
- [更名] `lib/features/live/multiview/widgets/multiview_room_picker.dart` → `lib/domains/live/presentation/multiview/widgets/multiview_room_picker.dart`
- [更名] `lib/features/live/multiview/widgets/video_output_viewport_sizer.dart` → `lib/domains/live/presentation/multiview/widgets/video_output_viewport_sizer.dart`
- [更名] `lib/core/pagination/live_directory_controller.dart` → `lib/domains/live/presentation/pagination/live_directory_controller.dart`
- [更名] `lib/features/live/playback/controllers/danmaku_controller.dart` → `lib/domains/live/presentation/playback/controllers/danmaku_controller.dart`
- [更名] `lib/features/live/playback/controllers/danmaku_presentation_recovery.dart` → `lib/domains/live/presentation/playback/controllers/danmaku_presentation_recovery.dart`
- [更名] `lib/features/live/playback/controllers/danmaku_session_host.dart` → `lib/domains/live/presentation/playback/controllers/danmaku_session_host.dart`
- [更名] `lib/features/live/playback/controllers/live_play_controller.dart` → `lib/domains/live/presentation/playback/controllers/live_play_controller.dart`
- [更名] `lib/features/live/playback/controllers/player_controller.dart` → `lib/domains/live/presentation/playback/controllers/player_controller.dart`
- [更名] `lib/features/live/playback/controllers/timer_controller.dart` → `lib/domains/live/presentation/playback/controllers/timer_controller.dart`
- [更名] `lib/features/live/playback/dialogs/known_room_link_dialog.dart` → `lib/domains/live/presentation/playback/dialogs/known_room_link_dialog.dart`
- [更名] `lib/features/live/playback/dialogs/live_dlna_dialog.dart` → `lib/domains/live/presentation/playback/dialogs/live_dlna_dialog.dart`
- [更名] `lib/features/live/playback/dialogs/play_other.dart` → `lib/domains/live/presentation/playback/dialogs/play_other.dart`
- [更名] `lib/features/live/playback/dialogs/room_timer_dialog.dart` → `lib/domains/live/presentation/playback/dialogs/room_timer_dialog.dart`
- [更名] `lib/features/live/playback/dialogs/room_volume_dialog.dart` → `lib/domains/live/presentation/playback/dialogs/room_volume_dialog.dart`
- [更名] `lib/features/live/playback/pages/danmaku_settings_page.dart` → `lib/domains/live/presentation/playback/pages/danmaku_settings_page.dart`
- [更名] `lib/features/live/playback/pages/keyword_block_page.dart` → `lib/domains/live/presentation/playback/pages/keyword_block_page.dart`
- [更名] `lib/features/live/playback/pages/live_play_page.dart` → `lib/domains/live/presentation/playback/pages/live_play_page.dart`
- [更名] `lib/features/live/playback/pages/super_chat_page.dart` → `lib/domains/live/presentation/playback/pages/super_chat_page.dart`
- [更名] `lib/features/live/playback/services/android_predictive_back_service.dart` → `lib/domains/live/presentation/playback/services/android_predictive_back_service.dart`
- [新增] `lib/domains/live/presentation/playback/services/room_external_opener.dart`
- [更名] `lib/features/live/playback/states/danmaku_state.dart` → `lib/domains/live/presentation/playback/states/danmaku_state.dart`
- [更名] `lib/features/live/playback/states/live_play_state.dart` → `lib/domains/live/presentation/playback/states/live_play_state.dart`
- [更名] `lib/features/live/playback/states/player_state.dart` → `lib/domains/live/presentation/playback/states/player_state.dart`
- [更名] `lib/features/live/playback/states/room_state.dart` → `lib/domains/live/presentation/playback/states/room_state.dart`
- [更名] `lib/features/live/playback/states/ui_state.dart` → `lib/domains/live/presentation/playback/states/ui_state.dart`
- [更名] `lib/features/live/playback/widgets/button/favorite_floating_button.dart` → `lib/domains/live/presentation/playback/widgets/button/favorite_floating_button.dart`
- [更名] `lib/features/live/playback/widgets/button/live_play_menu_button.dart` → `lib/domains/live/presentation/playback/widgets/button/live_play_menu_button.dart`
- [更名] `lib/features/live/playback/widgets/content_first_panel_layout.dart` → `lib/domains/live/presentation/playback/widgets/content_first_panel_layout.dart`
- [更名] `lib/features/live/playback/widgets/danmaku/compact_danmaku_metrics.dart` → `lib/domains/live/presentation/playback/widgets/danmaku/compact_danmaku_metrics.dart`
- [更名] `lib/features/live/playback/widgets/danmaku/compact_danmaku_overlay.dart` → `lib/domains/live/presentation/playback/widgets/danmaku/compact_danmaku_overlay.dart`
- [更名] `lib/features/live/playback/widgets/danmaku/danmaku_arrival_counter.dart` → `lib/domains/live/presentation/playback/widgets/danmaku/danmaku_arrival_counter.dart`
- [更名] `lib/features/live/playback/widgets/danmaku/danmaku_list_view.dart` → `lib/domains/live/presentation/playback/widgets/danmaku/danmaku_list_view.dart`
- [更名] `lib/features/live/playback/widgets/danmaku/danmaku_message_actions.dart` → `lib/domains/live/presentation/playback/widgets/danmaku/danmaku_message_actions.dart`
- [更名] `lib/features/live/playback/widgets/danmaku/danmaku_settings_source.dart` → `lib/domains/live/presentation/playback/widgets/danmaku/danmaku_settings_source.dart`
- [更名] `lib/features/live/playback/widgets/danmaku/danmaku_tab.dart` → `lib/domains/live/presentation/playback/widgets/danmaku/danmaku_tab.dart`
- [更名] `lib/features/live/playback/widgets/danmaku/danmaku_viewing_preset.dart` → `lib/domains/live/presentation/playback/widgets/danmaku/danmaku_viewing_preset.dart`
- [新增] `lib/domains/live/presentation/playback/widgets/danmaku/portrait_danmaku_policy.dart`
- [更名] `lib/features/live/playback/widgets/keyboard/video_keyboard.dart` → `lib/domains/live/presentation/playback/widgets/keyboard/video_keyboard.dart`
- [更名] `lib/features/live/playback/widgets/layout/bottom_control_surface.dart` → `lib/domains/live/presentation/playback/widgets/layout/bottom_control_surface.dart`
- [更名] `lib/features/live/playback/widgets/layout/control_hover_region.dart` → `lib/domains/live/presentation/playback/widgets/layout/control_hover_region.dart`
- [更名] `lib/features/live/playback/widgets/layout/live_play_back_scope.dart` → `lib/domains/live/presentation/playback/widgets/layout/live_play_back_scope.dart`
- [更名] `lib/features/live/playback/widgets/layout/live_play_content.dart` → `lib/domains/live/presentation/playback/widgets/layout/live_play_content.dart`
- [更名] `lib/features/live/playback/widgets/layout/live_play_header.dart` → `lib/domains/live/presentation/playback/widgets/layout/live_play_header.dart`
- [更名] `lib/features/live/playback/widgets/layout/live_play_video.dart` → `lib/domains/live/presentation/playback/widgets/layout/live_play_video.dart`
- [更名] `lib/features/live/playback/widgets/layout/portrait_fullscreen_interaction.dart` → `lib/domains/live/presentation/playback/widgets/layout/portrait_fullscreen_interaction.dart`
- [更名] `lib/features/live/playback/widgets/layout/super_chat_card.dart` → `lib/domains/live/presentation/playback/widgets/layout/super_chat_card.dart`
- [更名] `lib/features/live/playback/widgets/local_interaction/local_danmaku_style_editor.dart` → `lib/domains/live/presentation/playback/widgets/local_interaction/local_danmaku_style_editor.dart`
- [更名] `lib/features/live/playback/widgets/local_interaction/local_interaction_controller.dart` → `lib/domains/live/presentation/playback/widgets/local_interaction/local_interaction_controller.dart`
- [更名] `lib/features/live/playback/widgets/local_interaction/local_interaction_sheet.dart` → `lib/domains/live/presentation/playback/widgets/local_interaction/local_interaction_sheet.dart`
- [更名] `lib/features/live/playback/widgets/local_interaction/local_message_delivery_queue.dart` → `lib/domains/live/presentation/playback/widgets/local_interaction/local_message_delivery_queue.dart`
- [更名] `lib/features/live/playback/widgets/placeholder/not_living_video_widget.dart` → `lib/domains/live/presentation/playback/widgets/placeholder/not_living_video_widget.dart`
- [更名] `lib/features/live/playback/widgets/resolution_selector/audience_info.dart` → `lib/domains/live/presentation/playback/widgets/resolution_selector/audience_info.dart`
- [更名] `lib/features/live/playback/widgets/resolution_selector/line_selector.dart` → `lib/domains/live/presentation/playback/widgets/resolution_selector/line_selector.dart`
- [更名] `lib/features/live/playback/widgets/resolution_selector/resolution_selector.dart` → `lib/domains/live/presentation/playback/widgets/resolution_selector/resolution_selector.dart`
- [更名] `lib/features/live/playback/widgets/resolution_selector/resolutions_row.dart` → `lib/domains/live/presentation/playback/widgets/resolution_selector/resolutions_row.dart`
- [更名] `lib/features/live/playback/widgets/video_player/iptv_programme_policy.dart` → `lib/domains/live/presentation/playback/widgets/video_player/iptv_programme_policy.dart`
- [更名] `lib/features/live/playback/widgets/video_player/iptv_schedule_dialog.dart` → `lib/domains/live/presentation/playback/widgets/video_player/iptv_schedule_dialog.dart`
- [更名] `lib/features/live/playback/widgets/video_player/playback_failure_overlay.dart` → `lib/domains/live/presentation/playback/widgets/video_player/playback_failure_overlay.dart`
- [更名] `lib/features/live/playback/widgets/video_player/portrait_playback_picker_dialog.dart` → `lib/domains/live/presentation/playback/widgets/video_player/portrait_playback_picker_dialog.dart`
- [更名] `lib/features/live/playback/widgets/video_player/video_controller.dart` → `lib/domains/live/presentation/playback/widgets/video_player/video_controller.dart`
- [更名] `lib/features/live/playback/widgets/video_player/video_controller_panel.dart` → `lib/domains/live/presentation/playback/widgets/video_player/video_controller_panel.dart`
- [更名] `lib/features/live/playback/widgets/video_player/video_loading.dart` → `lib/domains/live/presentation/playback/widgets/video_player/video_loading.dart`
- [更名] `lib/features/live/playback/widgets/video_player/video_player.dart` → `lib/domains/live/presentation/playback/widgets/video_player/video_player.dart`
- [更名] `lib/features/live/playback/widgets/video_player/volume_control.dart` → `lib/domains/live/presentation/playback/widgets/video_player/volume_control.dart`
- [更名] `lib/features/live/popular/popular_controller.dart` → `lib/domains/live/presentation/popular/popular_controller.dart`
- [更名] `lib/features/live/popular/popular_grid_controller.dart` → `lib/domains/live/presentation/popular/popular_grid_controller.dart`
- [更名] `lib/features/live/popular/popular_grid_view.dart` → `lib/domains/live/presentation/popular/popular_grid_view.dart`
- [更名] `lib/features/live/popular/popular_page.dart` → `lib/domains/live/presentation/popular/popular_page.dart`
- [更名] `lib/features/live/search/search_capability.dart` → `lib/domains/live/presentation/search/search_capability.dart`
- [更名] `lib/features/live/search/search_controller.dart` → `lib/domains/live/presentation/search/search_controller.dart`
- [更名] `lib/features/live/search/search_page.dart` → `lib/domains/live/presentation/search/search_page.dart`
- [更名] `lib/features/live/search/search_platform_strip.dart` → `lib/domains/live/presentation/search/search_platform_strip.dart`
- [更名] `lib/features/live/search/search_ranking.dart` → `lib/domains/live/presentation/search/search_ranking.dart`
- [更名] `lib/features/live/search/web_search_controller.dart` → `lib/domains/live/presentation/search/web_search_controller.dart`
- [更名] `lib/features/live/search/web_search_page.dart` → `lib/domains/live/presentation/search/web_search_page.dart`
- [更名] `lib/features/live/shield/danmu_shield_controller.dart` → `lib/domains/live/presentation/shield/danmu_shield_controller.dart`
- [更名] `lib/features/live/shield/danmu_shield_page.dart` → `lib/domains/live/presentation/shield/danmu_shield_page.dart`
- [更名] `lib/features/live/tags/live_tag.dart` → `lib/domains/live/presentation/tags/live_tag.dart`
- [更名] `lib/features/live/tags/tag_management_controller.dart` → `lib/domains/live/presentation/tags/tag_management_controller.dart`
- [更名] `lib/features/live/tags/tag_management_page.dart` → `lib/domains/live/presentation/tags/tag_management_page.dart`
- [新增] `lib/domains/live/presentation/widgets/platform_tab.dart`
- [更名] `lib/core/widgets/room_card.dart` → `lib/domains/live/presentation/widgets/room_card.dart`
- [更名] `lib/core/widgets/room_card_layout.dart` → `lib/domains/live/presentation/widgets/room_card_layout.dart`
- [更名] `lib/features/recorder/consts/recorder_config.dart` → `lib/domains/recorder/data/consts/recorder_config.dart`
- [更名] `lib/features/recorder/consts/recorder_keys.dart` → `lib/domains/recorder/data/consts/recorder_keys.dart`
- [更名] `lib/features/recorder/ffmpeg/ffmpeg_command_builder.dart` → `lib/domains/recorder/data/ffmpeg/ffmpeg_command_builder.dart`
- [更名] `lib/features/recorder/ffmpeg/ffmpeg_event.dart` → `lib/domains/recorder/data/ffmpeg/ffmpeg_event.dart`
- [更名] `lib/features/recorder/ffmpeg/ffmpeg_manager.dart` → `lib/domains/recorder/data/ffmpeg/ffmpeg_manager.dart`
- [更名] `lib/features/recorder/ffmpeg/ffmpeg_scheduler.dart` → `lib/domains/recorder/data/ffmpeg/ffmpeg_scheduler.dart`
- [更名] `lib/features/recorder/ffmpeg/ffmpeg_types.dart` → `lib/domains/recorder/data/ffmpeg/ffmpeg_types.dart`
- [更名] `lib/features/recorder/pages/record_settings/record_settings_controller.dart` → `lib/domains/recorder/data/record_settings_controller.dart`
- [更名] `lib/features/recorder/services/bigo_hls_input.dart` → `lib/domains/recorder/data/services/bigo_hls_input.dart`
- [更名] `lib/features/recorder/services/cache_service.dart` → `lib/domains/recorder/data/services/cache_service.dart`
- [更名] `lib/features/recorder/services/cancellable_http_connections.dart` → `lib/domains/recorder/data/services/cancellable_http_connections.dart`
- [更名] `lib/features/recorder/services/fc2_hls_input.dart` → `lib/domains/recorder/data/services/fc2_hls_input.dart`
- [更名] `lib/features/recorder/services/ffmpeg_header_factory.dart` → `lib/domains/recorder/data/services/ffmpeg_header_factory.dart`
- [更名] `lib/features/recorder/services/ffmpeg_hls_input_relay.dart` → `lib/domains/recorder/data/services/ffmpeg_hls_input_relay.dart`
- [更名] `lib/features/recorder/services/ffmpeg_service.dart` → `lib/domains/recorder/data/services/ffmpeg_service.dart`
- [更名] `lib/features/recorder/services/ffmpeg_tls_trust_store.dart` → `lib/domains/recorder/data/services/ffmpeg_tls_trust_store.dart`
- [更名] `lib/features/recorder/services/hls_body_reader.dart` → `lib/domains/recorder/data/services/hls_body_reader.dart`
- [更名] `lib/features/recorder/services/hls_date_range.dart` → `lib/domains/recorder/data/services/hls_date_range.dart`
- [更名] `lib/features/recorder/services/hls_http_body_metadata.dart` → `lib/domains/recorder/data/services/hls_http_body_metadata.dart`
- [更名] `lib/features/recorder/services/hls_low_latency.dart` → `lib/domains/recorder/data/services/hls_low_latency.dart`
- [更名] `lib/features/recorder/services/hls_media_spool.dart` → `lib/domains/recorder/data/services/hls_media_spool.dart`
- [更名] `lib/features/recorder/services/hls_prefetch_plan.dart` → `lib/domains/recorder/data/services/hls_prefetch_plan.dart`
- [更名] `lib/features/recorder/services/hls_prefetch_pool.dart` → `lib/domains/recorder/data/services/hls_prefetch_pool.dart`
- [更名] `lib/features/recorder/services/hls_prefetch_scheduler.dart` → `lib/domains/recorder/data/services/hls_prefetch_scheduler.dart`
- [更名] `lib/features/recorder/services/hls_relay_diagnostics.dart` → `lib/domains/recorder/data/services/hls_relay_diagnostics.dart`
- [更名] `lib/features/recorder/services/hls_relay_prefetch.dart` → `lib/domains/recorder/data/services/hls_relay_prefetch.dart`
- [更名] `lib/features/recorder/services/hls_retained_manifest.dart` → `lib/domains/recorder/data/services/hls_retained_manifest.dart`
- [更名] `lib/features/recorder/services/hls_retained_window.dart` → `lib/domains/recorder/data/services/hls_retained_window.dart`
- [更名] `lib/features/recorder/services/hls_upstream_client.dart` → `lib/domains/recorder/data/services/hls_upstream_client.dart`
- [更名] `lib/features/recorder/services/live_input_recording_binder.dart` → `lib/domains/recorder/data/services/live_input_recording_binder.dart`
- [更名] `lib/features/recorder/services/niconico_hls_input.dart` → `lib/domains/recorder/data/services/niconico_hls_input.dart`
- [更名] `lib/features/recorder/services/owned_record_input.dart` → `lib/domains/recorder/data/services/owned_record_input.dart`
- [更名] `lib/features/recorder/services/path_helper.dart` → `lib/domains/recorder/data/services/path_helper.dart`
- [更名] `lib/features/recorder/services/recorder_background_service.dart` → `lib/domains/recorder/data/services/recorder_background_service.dart`
- [更名] `lib/features/recorder/services/recorder_continuation_policy.dart` → `lib/domains/recorder/data/services/recorder_continuation_policy.dart`
- [更名] `lib/features/recorder/services/recorder_diagnostics.dart` → `lib/domains/recorder/data/services/recorder_diagnostics.dart`
- [更名] `lib/features/recorder/services/recording_bitrate_window.dart` → `lib/domains/recorder/data/services/recording_bitrate_window.dart`
- [更名] `lib/features/recorder/services/recording_danmaku_service.dart` → `lib/domains/recorder/data/services/recording_danmaku_service.dart`
- [更名] `lib/features/recorder/services/recording_output_metrics.dart` → `lib/domains/recorder/data/services/recording_output_metrics.dart`
- [更名] `lib/features/recorder/services/recording_segment_clock.dart` → `lib/domains/recorder/data/services/recording_segment_clock.dart`
- [更名] `lib/features/recorder/services/stream_resolver_service.dart` → `lib/domains/recorder/data/services/stream_resolver_service.dart`
- [更名] `lib/features/recorder/services/video_processor_service.dart` → `lib/domains/recorder/data/services/video_processor_service.dart`
- [更名] `lib/features/recorder/models/live_record_task.dart` → `lib/domains/recorder/domain/models/live_record_task.dart`
- [更名] `lib/features/recorder/models/record_file_item.dart` → `lib/domains/recorder/domain/models/record_file_item.dart`
- [更名] `lib/features/recorder/models/record_status.dart` → `lib/domains/recorder/domain/models/record_status.dart`
- [更名] `lib/features/recorder/models/recorder_task_ordering.dart` → `lib/domains/recorder/domain/models/recorder_task_ordering.dart`
- [更名] `lib/features/recorder/pages/record_settings/record_settings_page.dart` → `lib/domains/recorder/presentation/pages/record_settings/record_settings_page.dart`
- [更名] `lib/features/recorder/pages/recorder/recorder_controller.dart` → `lib/domains/recorder/presentation/pages/recorder/recorder_controller.dart`
- [更名] `lib/features/recorder/pages/recorder/recorder_page.dart` → `lib/domains/recorder/presentation/pages/recorder/recorder_page.dart`
- [更名] `lib/features/live/playback/widgets/button/record_action_button.dart` → `lib/domains/recorder/presentation/widgets/record_action_button.dart`
- [更名] `lib/features/live/playback/widgets/button/record_action_content.dart` → `lib/domains/recorder/presentation/widgets/record_action_content.dart`
- [更名] `lib/features/recorder/widgets/recorder_bounded_scroll.dart` → `lib/domains/recorder/presentation/widgets/recorder_bounded_scroll.dart`
- [更名] `lib/services/background/itab_client.dart` → `lib/domains/wallpaper/data/itab_client.dart`
- [更名] `lib/services/background/local_wallpapers.dart` → `lib/domains/wallpaper/data/local_wallpapers.dart`
- [新增] `lib/domains/wallpaper/data/wallpaper_api_client.dart`
- [更名] `lib/services/background/wallpaper_media_store.dart` → `lib/domains/wallpaper/data/wallpaper_media_store.dart`
- [更名] `lib/services/background/wallpaper_presets.dart` → `lib/domains/wallpaper/data/wallpaper_presets.dart`
- [更名] `lib/services/background/wallpaper_repository.dart` → `lib/domains/wallpaper/data/wallpaper_repository.dart`
- [更名] `lib/services/background/background_controller.dart` → `lib/domains/wallpaper/domain/background_controller.dart`
- [新增] `lib/domains/wallpaper/domain/wallpaper_api_catalog.dart`
- [更名] `lib/services/background/wallpaper_catalog.dart` → `lib/domains/wallpaper/domain/wallpaper_catalog.dart`
- [新增] `lib/domains/wallpaper/presentation/app_background.dart`
- [新增] `lib/domains/wallpaper/presentation/wallpaper_api_group_page.dart`
- [新增] `lib/domains/wallpaper/presentation/wallpaper_api_page.dart`
- [新增] `lib/domains/wallpaper/presentation/wallpaper_display_options.dart`
- [新增] `lib/domains/wallpaper/presentation/wallpaper_gallery_page.dart`
- [新增] `lib/domains/wallpaper/presentation/wallpaper_grid_controller.dart`
- [新增] `lib/domains/wallpaper/presentation/wallpaper_image.dart`
- [新增] `lib/domains/wallpaper/presentation/wallpaper_items_page.dart`
- [新增] `lib/domains/wallpaper/presentation/wallpaper_library_page.dart`
- [更名] `lib/features/wallpaper/wallpaper_page.dart` → `lib/domains/wallpaper/presentation/wallpaper_page.dart`
- [新增] `lib/domains/wallpaper/presentation/wallpaper_preview_page.dart`
- [新增] `lib/domains/wallpaper/presentation/wallpaper_tile.dart`

### lib/features/ (39)

- [更名] `lib/services/settings/backup_controller.dart` → `lib/features/backup/backup_controller.dart`
- [修改] `lib/features/backup/backup_page.dart`
- [修改] `lib/features/backup/backup_recovery_service.dart`
- [新增] `lib/features/backup/backup_section_picker.dart`
- [修改] `lib/features/backup/scan_page.dart`
- [修改] `lib/features/home/home_page.dart`
- [修改] `lib/features/home/tablet_view.dart`
- [删除] `lib/features/live/playback/services/room_external_opener.dart`
- [删除] `lib/features/recorder/services/recorder_proxy_routing.dart`
- [修改] `lib/features/remote_receiver/remote_sync_page.dart`
- [修改] `lib/features/remote_receiver/remote_sync_protocol.dart`
- [修改] `lib/features/remote_receiver/remote_sync_service.dart`
- [修改] `lib/features/settings/pages/audience_metric_settings_page.dart`
- [修改] `lib/features/settings/pages/cache_data_settings_page.dart`
- [修改] `lib/features/settings/pages/font_family_manager_page.dart`
- [修改] `lib/features/settings/pages/font_settings_page.dart`
- [修改] `lib/features/settings/pages/general_settings_page.dart`
- [修改] `lib/features/settings/pages/local_config_preview_page.dart`
- [修改] `lib/features/settings/pages/local_interaction_settings_page.dart`
- [修改] `lib/features/settings/pages/mpv_option_page.dart`
- [修改] `lib/features/settings/pages/navigation_settings_page.dart`
- [修改] `lib/features/settings/pages/page_settings_page.dart`
- [修改] `lib/features/settings/pages/platform_settings_page.dart`
- [修改] `lib/features/settings/pages/player_kernel_settings_page.dart`
- [修改] `lib/features/settings/pages/player_preset_page.dart`
- [修改] `lib/features/settings/pages/player_super_resolution_page.dart`
- [修改] `lib/features/settings/pages/portrait_live_settings_page.dart`
- [修改] `lib/features/settings/pages/refresh_settings_page.dart`
- [修改] `lib/features/settings/pages/room_card_settings_page.dart`
- [修改] `lib/features/settings/pages/theme_settings_page.dart`
- [修改] `lib/features/settings/pages/video_settings_page.dart`
- [修改] `lib/features/settings/settings_page.dart`
- [修改] `lib/features/toolbox/toolbox_controller.dart`
- [修改] `lib/features/version/app_update_flow.dart`
- [删除] `lib/features/wallpaper/app_background.dart`
- [删除] `lib/features/wallpaper/wallpaper_library.dart`
- [修改] `lib/features/web_dav/web_dav_controller.dart`
- [修改] `lib/features/web_dav/web_dav_page.dart`
- [更名] `lib/services/settings/web_dav_controller.dart` → `lib/features/web_dav/web_dav_settings_controller.dart`

### lib/main.dart/ (1)

- [修改] `lib/main.dart`

### lib/platforms/ (2)

- [删除] `lib/platforms/chzzk/chzzk_link.dart`
- [删除] `lib/platforms/niconico/niconico_link.dart`

### lib/player/ (2)

- [删除] `lib/player/models/player_error_type.dart`
- [删除] `lib/player/models/player_state.dart`

### lib/services/ (2)

- [删除] `lib/services/index.dart`
- [删除] `lib/services/settings_service.dart`

### lib/shared/ (137)

- [更名] `lib/platforms/acfun/acfun_api.dart` → `lib/shared/platforms/acfun/acfun_api.dart`
- [更名] `lib/platforms/acfun/acfun_directory.dart` → `lib/shared/platforms/acfun/acfun_directory.dart`
- [更名] `lib/platforms/acfun/acfun_search.dart` → `lib/shared/platforms/acfun/acfun_search.dart`
- [更名] `lib/platforms/acfun/acfun_site.dart` → `lib/shared/platforms/acfun/acfun_site.dart`
- [更名] `lib/platforms/baidulive/baidu_live_api.dart` → `lib/shared/platforms/baidulive/baidu_live_api.dart`
- [更名] `lib/platforms/baidulive/baidu_live_link.dart` → `lib/shared/platforms/baidulive/baidu_live_link.dart`
- [更名] `lib/platforms/baidulive/baidu_live_site.dart` → `lib/shared/platforms/baidulive/baidu_live_site.dart`
- [更名] `lib/platforms/bigo/bigo_api.dart` → `lib/shared/platforms/bigo/bigo_api.dart`
- [更名] `lib/platforms/bigo/bigo_hls_protection.dart` → `lib/shared/platforms/bigo/bigo_hls_protection.dart`
- [更名] `lib/platforms/bigo/bigo_input_recipe.dart` → `lib/shared/platforms/bigo/bigo_input_recipe.dart`
- [更名] `lib/platforms/bigo/bigo_link.dart` → `lib/shared/platforms/bigo/bigo_link.dart`
- [更名] `lib/platforms/bigo/bigo_site.dart` → `lib/shared/platforms/bigo/bigo_site.dart`
- [更名] `lib/platforms/bigo/bigo_token.dart` → `lib/shared/platforms/bigo/bigo_token.dart`
- [更名] `lib/platforms/bilibili/bilibili_danmaku.dart` → `lib/shared/platforms/bilibili/bilibili_danmaku.dart`
- [新增] `lib/shared/platforms/bilibili/bilibili_danmaku_capability.dart`
- [更名] `lib/platforms/bilibili/bilibili_site.dart` → `lib/shared/platforms/bilibili/bilibili_site.dart`
- [更名] `lib/platforms/cc/cc_catalog.dart` → `lib/shared/platforms/cc/cc_catalog.dart`
- [新增] `lib/shared/platforms/cc/cc_danmaku_capability.dart`
- [更名] `lib/platforms/cc/cc_site.dart` → `lib/shared/platforms/cc/cc_site.dart`
- [更名] `lib/platforms/chzzk/chzzk_api.dart` → `lib/shared/platforms/chzzk/chzzk_api.dart`
- [新增] `lib/shared/platforms/chzzk/chzzk_link.dart`
- [更名] `lib/platforms/chzzk/chzzk_site.dart` → `lib/shared/platforms/chzzk/chzzk_site.dart`
- [新增] `lib/shared/platforms/current_live_room.dart`
- [新增] `lib/shared/platforms/danmaku_emoji.dart`
- [更名] `lib/platforms/douyin/abogus.dart` → `lib/shared/platforms/douyin/abogus.dart`
- [更名] `lib/platforms/douyin/douyin_audience.dart` → `lib/shared/platforms/douyin/douyin_audience.dart`
- [更名] `lib/platforms/douyin/douyin_danmaku.dart` → `lib/shared/platforms/douyin/douyin_danmaku.dart`
- [新增] `lib/shared/platforms/douyin/douyin_danmaku_capability.dart`
- [更名] `lib/platforms/douyin/douyin_request_params.dart` → `lib/shared/platforms/douyin/douyin_request_params.dart`
- [更名] `lib/platforms/douyin/douyin_search.dart` → `lib/shared/platforms/douyin/douyin_search.dart`
- [更名] `lib/platforms/douyin/douyin_site.dart` → `lib/shared/platforms/douyin/douyin_site.dart`
- [更名] `lib/platforms/douyin/douyin_utils.dart` → `lib/shared/platforms/douyin/douyin_utils.dart`
- [更名] `lib/platforms/douyin/douyin_xbogus.dart` → `lib/shared/platforms/douyin/douyin_xbogus.dart`
- [更名] `lib/platforms/douyin/proto/douyin.pb.dart` → `lib/shared/platforms/douyin/proto/douyin.pb.dart`
- [更名] `lib/platforms/douyin/proto/douyin.pbenum.dart` → `lib/shared/platforms/douyin/proto/douyin.pbenum.dart`
- [更名] `lib/platforms/douyin/proto/douyin.pbjson.dart` → `lib/shared/platforms/douyin/proto/douyin.pbjson.dart`
- [更名] `lib/platforms/douyin/proto/douyin.proto` → `lib/shared/platforms/douyin/proto/douyin.proto`
- [更名] `lib/platforms/douyu/douyu_danmaku.dart` → `lib/shared/platforms/douyu/douyu_danmaku.dart`
- [新增] `lib/shared/platforms/douyu/douyu_danmaku_capability.dart`
- [更名] `lib/platforms/douyu/douyu_site.dart` → `lib/shared/platforms/douyu/douyu_site.dart`
- [更名] `lib/core/emoji/emoji_manager.dart` → `lib/shared/platforms/emoji_manager.dart`
- [更名] `lib/core/contracts/empty_danmaku.dart` → `lib/shared/platforms/empty_danmaku.dart`
- [更名] `lib/platforms/fc2live/fc2_api.dart` → `lib/shared/platforms/fc2live/fc2_api.dart`
- [更名] `lib/platforms/fc2live/fc2_control_session.dart` → `lib/shared/platforms/fc2live/fc2_control_session.dart`
- [更名] `lib/platforms/fc2live/fc2_input_recipe.dart` → `lib/shared/platforms/fc2live/fc2_input_recipe.dart`
- [更名] `lib/platforms/fc2live/fc2_link.dart` → `lib/shared/platforms/fc2live/fc2_link.dart`
- [更名] `lib/platforms/fc2live/fc2_site.dart` → `lib/shared/platforms/fc2live/fc2_site.dart`
- [更名] `lib/platforms/huya/huya_danmaku.dart` → `lib/shared/platforms/huya/huya_danmaku.dart`
- [新增] `lib/shared/platforms/huya/huya_danmaku_capability.dart`
- [更名] `lib/platforms/huya/huya_request_params.dart` → `lib/shared/platforms/huya/huya_request_params.dart`
- [更名] `lib/platforms/huya/huya_site.dart` → `lib/shared/platforms/huya/huya_site.dart`
- [更名] `lib/platforms/huya/huya_transport_policy.dart` → `lib/shared/platforms/huya/huya_transport_policy.dart`
- [更名] `lib/platforms/huya/huya_utils.dart` → `lib/shared/platforms/huya/huya_utils.dart`
- [更名] `lib/platforms/inke/inke_api.dart` → `lib/shared/platforms/inke/inke_api.dart`
- [更名] `lib/platforms/inke/inke_site.dart` → `lib/shared/platforms/inke/inke_site.dart`
- [更名] `lib/platforms/jdlive/jd_live_api.dart` → `lib/shared/platforms/jdlive/jd_live_api.dart`
- [更名] `lib/platforms/jdlive/jd_live_link.dart` → `lib/shared/platforms/jdlive/jd_live_link.dart`
- [更名] `lib/platforms/jdlive/jd_live_site.dart` → `lib/shared/platforms/jdlive/jd_live_site.dart`
- [更名] `lib/platforms/kilakila/kilakila_api.dart` → `lib/shared/platforms/kilakila/kilakila_api.dart`
- [更名] `lib/platforms/kilakila/kilakila_link.dart` → `lib/shared/platforms/kilakila/kilakila_link.dart`
- [更名] `lib/platforms/kilakila/kilakila_site.dart` → `lib/shared/platforms/kilakila/kilakila_site.dart`
- [更名] `lib/platforms/kuaishou/kuaishou_danmaku.dart` → `lib/shared/platforms/kuaishou/kuaishou_danmaku.dart`
- [更名] `lib/platforms/kuaishou/kuaishou_site.dart` → `lib/shared/platforms/kuaishou/kuaishou_site.dart`
- [更名] `lib/platforms/kugoulive/kugou_live_api.dart` → `lib/shared/platforms/kugoulive/kugou_live_api.dart`
- [更名] `lib/platforms/kugoulive/kugou_live_link.dart` → `lib/shared/platforms/kugoulive/kugou_live_link.dart`
- [更名] `lib/platforms/kugoulive/kugou_live_site.dart` → `lib/shared/platforms/kugoulive/kugou_live_site.dart`
- [更名] `lib/core/contracts/live_danmaku.dart` → `lib/shared/platforms/live_danmaku.dart`
- [新增] `lib/shared/platforms/live_danmaku_capability.dart`
- [更名] `lib/core/contracts/live_directory.dart` → `lib/shared/platforms/live_directory.dart`
- [新增] `lib/shared/platforms/live_external_room.dart`
- [更名] `lib/core/contracts/live_input_recipe.dart` → `lib/shared/platforms/live_input_recipe.dart`
- [更名] `lib/core/contracts/live_quality_discovery.dart` → `lib/shared/platforms/live_quality_discovery.dart`
- [更名] `lib/core/contracts/live_search.dart` → `lib/shared/platforms/live_search.dart`
- [更名] `lib/core/link/live_short_link_session.dart` → `lib/shared/platforms/live_short_link_session.dart`
- [更名] `lib/core/contracts/live_site.dart` → `lib/shared/platforms/live_site.dart`
- [更名] `lib/platforms/liveme/liveme_api.dart` → `lib/shared/platforms/liveme/liveme_api.dart`
- [更名] `lib/platforms/liveme/liveme_link.dart` → `lib/shared/platforms/liveme/liveme_link.dart`
- [更名] `lib/platforms/liveme/liveme_signer.dart` → `lib/shared/platforms/liveme/liveme_signer.dart`
- [更名] `lib/platforms/liveme/liveme_site.dart` → `lib/shared/platforms/liveme/liveme_site.dart`
- [更名] `lib/platforms/looklive/look_live_api.dart` → `lib/shared/platforms/looklive/look_live_api.dart`
- [更名] `lib/platforms/looklive/look_live_link.dart` → `lib/shared/platforms/looklive/look_live_link.dart`
- [更名] `lib/platforms/looklive/look_live_site.dart` → `lib/shared/platforms/looklive/look_live_site.dart`
- [更名] `lib/platforms/missevan/missevan_api.dart` → `lib/shared/platforms/missevan/missevan_api.dart`
- [更名] `lib/platforms/missevan/missevan_site.dart` → `lib/shared/platforms/missevan/missevan_site.dart`
- [更名] `lib/platforms/niconico/niconico_api.dart` → `lib/shared/platforms/niconico/niconico_api.dart`
- [新增] `lib/shared/platforms/niconico/niconico_contract.dart`
- [更名] `lib/platforms/niconico/niconico_directory.dart` → `lib/shared/platforms/niconico/niconico_directory.dart`
- [更名] `lib/platforms/niconico/niconico_input_recipe.dart` → `lib/shared/platforms/niconico/niconico_input_recipe.dart`
- [新增] `lib/shared/platforms/niconico/niconico_link.dart`
- [更名] `lib/platforms/niconico/niconico_quality_catalog.dart` → `lib/shared/platforms/niconico/niconico_quality_catalog.dart`
- [更名] `lib/platforms/niconico/niconico_session.dart` → `lib/shared/platforms/niconico/niconico_session.dart`
- [更名] `lib/platforms/niconico/niconico_site.dart` → `lib/shared/platforms/niconico/niconico_site.dart`
- [更名] `lib/platforms/niconico/niconico_stream.dart` → `lib/shared/platforms/niconico/niconico_stream.dart`
- [更名] `lib/platforms/niconico/niconico_watch.dart` → `lib/shared/platforms/niconico/niconico_watch.dart`
- [更名] `lib/platforms/pandalive/pandalive_api.dart` → `lib/shared/platforms/pandalive/pandalive_api.dart`
- [更名] `lib/platforms/pandalive/pandalive_link.dart` → `lib/shared/platforms/pandalive/pandalive_link.dart`
- [更名] `lib/platforms/pandalive/pandalive_site.dart` → `lib/shared/platforms/pandalive/pandalive_site.dart`
- [更名] `lib/platforms/picarto/picarto_api.dart` → `lib/shared/platforms/picarto/picarto_api.dart`
- [更名] `lib/platforms/picarto/picarto_hls.dart` → `lib/shared/platforms/picarto/picarto_hls.dart`
- [更名] `lib/platforms/picarto/picarto_site.dart` → `lib/shared/platforms/picarto/picarto_site.dart`
- [更名] `lib/platforms/seventeenlive/seventeenlive_api.dart` → `lib/shared/platforms/seventeenlive/seventeenlive_api.dart`
- [更名] `lib/platforms/seventeenlive/seventeenlive_link.dart` → `lib/shared/platforms/seventeenlive/seventeenlive_link.dart`
- [更名] `lib/platforms/seventeenlive/seventeenlive_site.dart` → `lib/shared/platforms/seventeenlive/seventeenlive_site.dart`
- [更名] `lib/platforms/showroom/showroom_api.dart` → `lib/shared/platforms/showroom/showroom_api.dart`
- [更名] `lib/platforms/showroom/showroom_link.dart` → `lib/shared/platforms/showroom/showroom_link.dart`
- [更名] `lib/platforms/showroom/showroom_site.dart` → `lib/shared/platforms/showroom/showroom_site.dart`
- [更名] `lib/platforms/sixroom/sixroom_api.dart` → `lib/shared/platforms/sixroom/sixroom_api.dart`
- [更名] `lib/platforms/sixroom/sixroom_link.dart` → `lib/shared/platforms/sixroom/sixroom_link.dart`
- [更名] `lib/platforms/sixroom/sixroom_site.dart` → `lib/shared/platforms/sixroom/sixroom_site.dart`
- [更名] `lib/platforms/soop/soop_danmaku.dart` → `lib/shared/platforms/soop/soop_danmaku.dart`
- [更名] `lib/platforms/soop/soop_site.dart` → `lib/shared/platforms/soop/soop_site.dart`
- [更名] `lib/platforms/steambroadcast/steam_broadcast_api.dart` → `lib/shared/platforms/steambroadcast/steam_broadcast_api.dart`
- [更名] `lib/platforms/steambroadcast/steam_broadcast_link.dart` → `lib/shared/platforms/steambroadcast/steam_broadcast_link.dart`
- [更名] `lib/platforms/steambroadcast/steam_broadcast_site.dart` → `lib/shared/platforms/steambroadcast/steam_broadcast_site.dart`
- [更名] `lib/platforms/tiktok/tiktok_api.dart` → `lib/shared/platforms/tiktok/tiktok_api.dart`
- [更名] `lib/platforms/tiktok/tiktok_link.dart` → `lib/shared/platforms/tiktok/tiktok_link.dart`
- [更名] `lib/platforms/tiktok/tiktok_site.dart` → `lib/shared/platforms/tiktok/tiktok_site.dart`
- [更名] `lib/platforms/twitcasting/twitcasting_api.dart` → `lib/shared/platforms/twitcasting/twitcasting_api.dart`
- [更名] `lib/platforms/twitcasting/twitcasting_site.dart` → `lib/shared/platforms/twitcasting/twitcasting_site.dart`
- [更名] `lib/platforms/twitch/twitch_danmaku.dart` → `lib/shared/platforms/twitch/twitch_danmaku.dart`
- [更名] `lib/platforms/twitch/twitch_models.dart` → `lib/shared/platforms/twitch/twitch_models.dart`
- [更名] `lib/platforms/twitch/twitch_site.dart` → `lib/shared/platforms/twitch/twitch_site.dart`
- [更名] `lib/platforms/twitch/twitch_web_integrity.dart` → `lib/shared/platforms/twitch/twitch_web_integrity.dart`
- [更名] `lib/platforms/weibo/weibo_api.dart` → `lib/shared/platforms/weibo/weibo_api.dart`
- [更名] `lib/platforms/weibo/weibo_link.dart` → `lib/shared/platforms/weibo/weibo_link.dart`
- [更名] `lib/platforms/weibo/weibo_site.dart` → `lib/shared/platforms/weibo/weibo_site.dart`
- [更名] `lib/platforms/xiaohongshu/xiaohongshu_api.dart` → `lib/shared/platforms/xiaohongshu/xiaohongshu_api.dart`
- [更名] `lib/platforms/xiaohongshu/xiaohongshu_link.dart` → `lib/shared/platforms/xiaohongshu/xiaohongshu_link.dart`
- [更名] `lib/platforms/xiaohongshu/xiaohongshu_share.dart` → `lib/shared/platforms/xiaohongshu/xiaohongshu_share.dart`
- [更名] `lib/platforms/xiaohongshu/xiaohongshu_site.dart` → `lib/shared/platforms/xiaohongshu/xiaohongshu_site.dart`
- [更名] `lib/platforms/youtube/youtube_api.dart` → `lib/shared/platforms/youtube/youtube_api.dart`
- [更名] `lib/platforms/youtube/youtube_link.dart` → `lib/shared/platforms/youtube/youtube_link.dart`
- [更名] `lib/platforms/youtube/youtube_site.dart` → `lib/shared/platforms/youtube/youtube_site.dart`
- [更名] `lib/platforms/yy/yy_danmaku.dart` → `lib/shared/platforms/yy/yy_danmaku.dart`
- [更名] `lib/platforms/yy/yy_protocol.dart` → `lib/shared/platforms/yy/yy_protocol.dart`
- [更名] `lib/platforms/yy/yy_site.dart` → `lib/shared/platforms/yy/yy_site.dart`
- [更名] `lib/platforms/yy/yy_web_socket_channel.dart` → `lib/shared/platforms/yy/yy_web_socket_channel.dart`

### pubspec.lock/ (1)

- [修改] `pubspec.lock`

### pubspec.yaml/ (1)

- [修改] `pubspec.yaml`

### test/core/ (1)

- [新增] `test/core/theme/app_canvas_scope_test.dart`

### test/domains/ (3)

- [新增] `test/domains/live/area_display_config_test.dart`
- [新增] `test/domains/live/favorite_refresh_failure_summary_test.dart`
- [新增] `test/domains/wallpaper/wallpaper_canvas_transparency_test.dart`

### tool/_add_explicit_imports.py/ (1)

- [新增] `tool/_add_explicit_imports.py`

### tool/_i18n_inventory.py/ (1)

- [新增] `tool/_i18n_inventory.py`

### tool/_wire_current_room.py/ (1)

- [新增] `tool/_wire_current_room.py`

### tool/probes/ (59)

- [修改] `tool/probes/acfun_navigation_probe_test.dart`
- [修改] `tool/probes/acfun_public_contract_probe_test.dart`
- [修改] `tool/probes/acfun_recording_probe_test.dart`
- [修改] `tool/probes/all_sites_playback_probe_test.dart`
- [修改] `tool/probes/bigo_metadata_probe_test.dart`
- [修改] `tool/probes/bigo_snapshot_search_probe_test.dart`
- [修改] `tool/probes/cc_category_public_probe_test.dart`
- [修改] `tool/probes/cmaf_rendition_window_probe_test.dart`
- [修改] `tool/probes/danmaku_connection_matrix_probe_test.dart`
- [修改] `tool/probes/douyu_splice_probe_test.dart`
- [修改] `tool/probes/epg_backup_migration_probe_test.dart`
- [修改] `tool/probes/hls_production_byterange_probe_test.dart`
- [修改] `tool/probes/hls_retained_publication_probe_test.dart`
- [修改] `tool/probes/hls_rolling_delivery_probe_test.dart`
- [修改] `tool/probes/huya_message_board_probe_test.dart`
- [修改] `tool/probes/huya_native_transport_probe_test.dart`
- [修改] `tool/probes/huya_recorder_continuity_probe_test.dart`
- [修改] `tool/probes/inke_public_contract_probe_test.dart`
- [修改] `tool/probes/inke_showcase_search_probe_test.dart`
- [修改] `tool/probes/itab_wallpaper_probe_test.dart`
- [修改] `tool/probes/kilakila_application_probe_test.dart`
- [修改] `tool/probes/kilakila_keyword_search_probe_test.dart`
- [修改] `tool/probes/kilakila_link_probe_test.dart`
- [修改] `tool/probes/kilakila_owner_probe_test.dart`
- [修改] `tool/probes/kilakila_public_contract_probe_test.dart`
- [修改] `tool/probes/kilakila_recording_probe_test.dart`
- [修改] `tool/probes/media_kit_buffering_probe_test.dart`
- [修改] `tool/probes/missevan_keyword_search_probe_test.dart`
- [修改] `tool/probes/missevan_public_contract_probe_test.dart`
- [修改] `tool/probes/missevan_recording_probe_test.dart`
- [修改] `tool/probes/niconico_directory_probe_test.dart`
- [修改] `tool/probes/niconico_manager_probe_test.dart`
- [修改] `tool/probes/niconico_metadata_probe_test.dart`
- [修改] `tool/probes/niconico_playback_probe_test.dart`
- [修改] `tool/probes/niconico_relay_probe_test.dart`
- [修改] `tool/probes/niconico_session_probe_test.dart`
- [修改] `tool/probes/niconico_site_probe_test.dart`
- [修改] `tool/probes/pandalive_native_search_probe_test.dart`
- [修改] `tool/probes/picarto_public_contract_probe_test.dart`
- [修改] `tool/probes/recorder_clock_matrix_probe_test.dart`
- [修改] `tool/probes/recorder_controller_native_probe_test.dart`
- [修改] `tool/probes/recorder_flv_access_unit_probe_test.dart`
- [修改] `tool/probes/recorder_flv_stop_probe_test.dart`
- [修改] `tool/probes/recorder_hls_partial_stop_probe_test.dart`
- [修改] `tool/probes/recorder_hls_stop_probe_test.dart`
- [修改] `tool/probes/recorder_http_connection_benchmark.dart`
- [修改] `tool/probes/recorder_input_integrity_probe_test.dart`
- [修改] `tool/probes/recorder_segment_clock_probe_test.dart`
- [修改] `tool/probes/recorder_source_integrity_probe_test.dart`
- [修改] `tool/probes/recording_clock_probe_support.dart`
- [修改] `tool/probes/seventeenlive_public_catalog_probe_test.dart`
- [修改] `tool/probes/twitcasting_hls_cookie_probe_test.dart`
- [修改] `tool/probes/twitcasting_public_contract_probe_test.dart`
- [修改] `tool/probes/weibo_metadata_probe_test.dart`
- [修改] `tool/probes/weibo_recording_probe_test.dart`
- [修改] `tool/probes/xiaohongshu_application_probe_test.dart`
- [修改] `tool/probes/xiaohongshu_controller_native_probe_test.dart`
- [修改] `tool/probes/xiaohongshu_share_link_probe_test.dart`
- [修改] `tool/probes/xiaohongshu_share_probe_test.dart`

### tool/validate_architecture.py/ (1)

- [新增] `tool/validate_architecture.py`
