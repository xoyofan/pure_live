/// zishu 风格录制中心(pure_live 独有功能,zishu 无对应页面——
/// 按 zishu 设计语言全新绘制)。
///
/// 结构对齐 zishu_app 既有页头 + 工具行 + 内容列的骨架
/// (`zishu_follow_view.dart`):标题行(标题 + 打开目录/录制设置两个
/// 图标钮)+ 状态九档筛选 chips 行 + 任务卡列表。数据与操作全部走
/// pure_live 既有 `RecorderController`,只重绘视觉、不改数据层:
/// - 任务流:`controller.tasks`(RxList)在 [Obx] 内按档过滤,
///   排序沿用 `RecorderTaskOrdering.forDisplay`(全部档按状态分组,
///   单状态档按最新会话优先,与原页口径一致);
/// - 打开目录:`controller.openFileDir`;录制设置:`Get.toNamed(RoutePath.kRecordSettings)`;
/// - 空态:zishu [zishu.EmptyView](以 `as zishu` 前缀引用,避免与
///   pure_live common 的同名 EmptyView 混淆)。
///
/// 本视图为可嵌入视图(不自带 Scaffold/背景),宿主用 Scaffold 包裹,
/// 同 `ZishuSettingsView` 的接线方式。
library;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/recorder/models/recorder_task_ordering.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/empty_view.dart' as zishu;
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/record/zishu_record_task_card.dart';
import 'package:pure_live/zishu_app/features/record/zishu_recorder_filters.dart';

/// zishu 录制中心视图(无参构造;控制器自取)。
class ZishuRecorderView extends StatelessWidget {
  const ZishuRecorderView({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<RecorderController>()) {
      // RecorderController 由 RecorderBinding 懒注册(Bind.lazyPut/fenix);
      // 宿主未经录制页路由直接嵌本视图时的启动早期占位。
      return const Center(child: CircularProgressIndicator());
    }
    return _ZishuRecorderBody(controller: Get.find<RecorderController>());
  }
}

/// 页面本体:唯一的视图私有状态是「当前筛选档」(原页为
/// DefaultTabController 的 tabIndex,这里等价收敛为枚举下标),
/// 其余状态全在控制器。
class _ZishuRecorderBody extends StatefulWidget {
  const _ZishuRecorderBody({required this.controller});

  final RecorderController controller;

  @override
  State<_ZishuRecorderBody> createState() => _ZishuRecorderBodyState();
}

class _ZishuRecorderBodyState extends State<_ZishuRecorderBody> {
  ZishuRecordFilter _filter = ZishuRecordFilter.all;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context),
        _buildFilterBar(),
        Expanded(child: _buildTaskList()),
      ],
    );
  }

  /// 标题 + 打开目录 / 录制设置行(对齐 zishu 头部骨架:标题 headline 档,
  /// 右侧图标钮 20px 次级色)。
  Widget _buildHeader(BuildContext context) {
    final controller = widget.controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        children: [
          Text(i18n('recorder_title'), style: context.textTitle.copyWith(fontSize: AppFontSize.headline)),
          const Spacer(),
          IconButton(
            tooltip: i18n('recorder_open_folder'),
            onPressed: controller.openFileDir,
            icon: Icon(Icons.folder_open_rounded, size: 20, color: context.tokens.textSecondary),
          ),
          IconButton(
            tooltip: i18n('settings_title'),
            onPressed: () => Get.toNamed(RoutePath.kRecordSettings),
            icon: Icon(Icons.settings_outlined, size: 20, color: context.tokens.textSecondary),
          ),
        ],
      ),
    );
  }

  /// 状态九档筛选 chips 行(Wrap 自适应;选中态/状态圆点见筛选文件)。
  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      child: ZishuRecorderStatusFilter(
        selectedIndex: _filter.index,
        onSelected: (index) => setState(() => _filter = ZishuRecordFilter.values[index]),
      ),
    );
  }

  /// 任务列表:`tasks` 在 Obx 内按档过滤 + 既有排序口径;空态换 zishu
  /// EmptyView(标题档文案,图标沿用原页的视频合集图标)。
  Widget _buildTaskList() {
    final controller = widget.controller;
    return Obx(() {
      final list = RecorderTaskOrdering.forDisplay(
        controller.tasks.where(_filter.matches),
        groupByStatus: _filter == ZishuRecordFilter.all,
      );

      if (list.isEmpty) {
        return Center(
          child: zishu.EmptyView(message: i18n('recorder_empty_title'), icon: Icons.video_collection_outlined),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, index) {
          final task = list[index];
          return ZishuRecordTaskCard(key: ValueKey(task.taskId), task: task, controller: controller);
        },
      );
    });
  }
}
