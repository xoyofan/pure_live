import 'dart:io';
import 'dart:async';
import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';
import 'package:move_to_desktop/move_to_desktop.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/modules/areas/areas_page.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu_app/shell/phone/zishu_phone_shell.dart';
import 'package:pure_live/zishu_app/shell/zishu_app_shell.dart';
import 'package:pure_live/common/global/initialized.dart';
import 'package:pure_live/player/models/player_engine.dart';
import 'package:pure_live/modules/popular/popular_page.dart';
import 'package:pure_live/modules/favorite/favorite_page.dart';
import 'package:pure_live/modules/about/widgets/version_dialog.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.updateCheckDelay = const Duration(seconds: 2),
    this.initializePackageInfo,
    this.checkForUpdate,
    this.hasNewVersion,
    this.updatePromptBuilder,
  });

  @visibleForTesting
  final Duration updateCheckDelay;

  @visibleForTesting
  final Future<void> Function()? initializePackageInfo;

  @visibleForTesting
  final Future<bool> Function()? checkForUpdate;

  @visibleForTesting
  final bool Function()? hasNewVersion;

  @visibleForTesting
  final WidgetBuilder? updatePromptBuilder;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  Timer? _resumeRefreshTimer;
  Timer? _updateCheckTimer;
  final FavoriteController favoriteController = Get.find<FavoriteController>();
  late final VoidCallback _favoriteTabListener;
  Worker? _savedMenuWorker;
  DateTime? _backgroundedAt;

  int _selectedIndex = 0;

  /// 窄屏外壳无内容分发(zishu_phone_shell.dart 直接 `Expanded(child: body)`)，
  /// 四个 tab 内容仍由本页按需提供；宽屏外壳 `_contentForMenu` 已全量接管
  /// 四个 tab(zishu 视图)，body 仅兜底、永不渲染。
  Widget _pageForMenu(HomeMenu menu) {
    switch (menu) {
      case HomeMenu.favorites:
        return const FavoritePage();
      case HomeMenu.popular:
        return const PopularPage();
      case HomeMenu.areas:
        return const AreasPage();
      case HomeMenu.record:
        return const RecorderPage();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncInitialIndex();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      if (Platform.isAndroid) {
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Theme.of(context).navigationBarTheme.backgroundColor,
          ),
        );
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }

      final initialRoom = AppInitializer().takeInitialRoom();
      if (initialRoom != null && mounted) {
        // MyApp prepares the global manager asynchronously while leaving the
        // native decoder cold. Reusing that same initialization Future keeps a
        // command-line room from racing a second manager into existence.
        if (!GlobalPlayerService.instance.initialized) {
          await GlobalPlayerService.instance.initialize(defaultEngine: PlayerEngine.mediaKit);
        }
        if (!mounted) return;
        await AppNavigator.toLiveRoomDetail(liveRoom: initialRoom);
      }
    });

    // Give the visible room snapshot first use of the network and build
    // isolate. The update check is low-priority background work and previously
    // competed with the cold-start room verification and image requests.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateCheckTimer = Timer(widget.updateCheckDelay, () {
        if (mounted) unawaited(_checkForStartupUpdate());
      });
    });

    _favoriteTabListener = () {
      if (mounted) {
        setState(() => _selectedIndex = favoriteController.tabBottomIndex.value);
      }
    };
    favoriteController.tabBottomIndex.addListener(_favoriteTabListener);

    _savedMenuWorker = ever(SettingsService.to.app.savedMenuIds, (v) {
      if (!mounted) {
        return;
      }
      List<String> value = List<String>.from(v as List);
      if (value.isEmpty) {
        setState(() {
          _selectedIndex = -1;
        });
        favoriteController.tabBottomIndex.value = -1;
        return;
      }
      final currentMenuId = _selectedIndex >= 0 && _selectedIndex < HomeMenu.values.length
          ? HomeMenu.values[_selectedIndex].id
          : null;
      if (currentMenuId == null || !value.contains(currentMenuId)) {
        final firstMenu = HomeMenu.fromId(value.first);
        if (firstMenu != null) {
          onDestinationSelected(firstMenu.index);
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _resumeRefreshTimer?.cancel();
      _backgroundedAt ??= DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt == null || DateTime.now().difference(backgroundedAt) < const Duration(seconds: 15)) return;

    if (_selectedIndex < 0 || _selectedIndex >= HomeMenu.values.length) return;
    final menu = HomeMenu.values[_selectedIndex];
    _resumeRefreshTimer?.cancel();
    _updateCheckTimer?.cancel();
    _resumeRefreshTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      if (menu == HomeMenu.popular && Get.isRegistered<PopularController>()) {
        unawaited(Get.find<PopularController>().refreshCurrentData());
      } else if (menu == HomeMenu.areas && Get.isRegistered<AreasController>()) {
        unawaited(Get.find<AreasController>().refreshCurrentData());
      }
    });
  }

  void _syncInitialIndex() {
    List<String> activeIds = SettingsService.to.app.savedMenuIds.v;
    if (activeIds.isNotEmpty) {
      final firstMenu = HomeMenu.fromId(activeIds.first);
      if (firstMenu != null) {
        _selectedIndex = firstMenu.index;
        favoriteController.tabBottomIndex.value = firstMenu.index;
      }
    }
  }

  void handMoveRefresh() {
    if (favoriteController.loadding.value) return;
    unawaited(favoriteController.refreshData());
  }

  void onDestinationSelected(int index) {
    if (index == _selectedIndex && index == HomeMenu.favorites.index) {
      handMoveRefresh();
      return;
    }
    if (mounted) {
      setState(() => _selectedIndex = index);
    }
    favoriteController.tabBottomIndex.value = index;
  }

  Future<void> _checkForStartupUpdate() async {
    try {
      await (widget.initializePackageInfo ?? VersionUtil.initPackageInfo)();
      if (!mounted) return;
      final checkForUpdate = widget.checkForUpdate ?? VersionUtil().checkUpdate;
      final succeeded = await checkForUpdate();
      final hasNewVersion = widget.hasNewVersion ?? VersionUtil.hasNewVersion;
      if (!mounted || !succeeded || !SettingsService.to.app.enableAutoCheckUpdate.v || !hasNewVersion()) {
        return;
      }
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: widget.updatePromptBuilder ?? (_) => const NewVersionDialog(),
      );
    } catch (error, stackTrace) {
      log('Startup update check skipped: $error', name: 'HomePage', error: error, stackTrace: stackTrace);
    }
  }

  void onBackButtonPressed(bool didPop, _) {
    if (!didPop) {
      MoveToDesktop().moveToDesktop();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: onBackButtonPressed,
      child: LayoutBuilder(
        builder: (context, constraint) {
          // 断点统一 zishu 口径(<768 窄屏外壳,≥768 宽屏外壳);
          // popular/areas 页内 Get.width<=680 的口径本轮不动。
          final bool isTablet = constraint.maxWidth >= AppBreakpoints.phone;

          return Obx(() {
            final activeMenuIds = List<String>.from(SettingsService.to.app.savedMenuIds.v);

            int adjustedIndex = _selectedIndex;

            if (activeMenuIds.isNotEmpty) {
              if (adjustedIndex < 0 || adjustedIndex >= HomeMenu.values.length) {
                final fallbackMenu = HomeMenu.fromId(activeMenuIds.first);
                if (fallbackMenu != null) {
                  adjustedIndex = fallbackMenu.index;
                }
              }
            } else {
              adjustedIndex = -1;
            }

            final bool hasActiveMenu = adjustedIndex >= 0 && adjustedIndex < HomeMenu.values.length;

            return !isTablet
                ? ZishuPhoneShell(
                    body: hasActiveMenu ? _pageForMenu(HomeMenu.values[adjustedIndex]) : const SizedBox.shrink(),
                    index: adjustedIndex,
                    activeMenuIds: activeMenuIds,
                    onDestinationSelected: onDestinationSelected,
                  )
                : ZishuAppShell(
                    // 宽屏外壳 _contentForMenu 覆盖全部四个 menu 且空菜单时
                    // 自渲染空态页，body 兜底分支不可达，传空渲染即可。
                    body: const SizedBox.shrink(),
                    index: adjustedIndex,
                    activeMenuIds: activeMenuIds,
                    onDestinationSelected: onDestinationSelected,
                  );
          });
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    favoriteController.tabBottomIndex.removeListener(_favoriteTabListener);
    _savedMenuWorker?.dispose();
    _resumeRefreshTimer?.cancel();
    _updateCheckTimer?.cancel();
    super.dispose();
  }
}
