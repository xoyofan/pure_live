import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/home/home_drawer_view.dart';

/// ☰ entry on the tab pages' AppBars (narrow layout). The drawer lives on the
/// shell Scaffold above the page's own Scaffold, so `Scaffold.of` cannot find
/// it from here — open it through the shell's GlobalKey instead.
class HomeDrawerButton extends StatelessWidget {
  const HomeDrawerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: i18n('menu'),
      icon: const Icon(Icons.menu_rounded),
      onPressed: () => HomeDrawerView.scaffoldKey.currentState?.openDrawer(),
    );
  }
}
