import 'package:flutter/material.dart';

/// First frame shown while the life-circle beans finish initializing, so the
/// app never sits on a blank native window. iOS/Android theme their native
/// launch surfaces separately, but macOS has no native launch screen, so this
/// Flutter-drawn splash keeps the JHenTai wordmark centered on every platform.
///
/// The background follows the system brightness (white in light / black in
/// dark) and the wordmark inverts against it. It is a deliberately plain
/// [MaterialApp] — none of the GetX/app services are available before the
/// beans initialize, so this must not depend on them.
class AppLaunchSplash extends StatefulWidget {
  const AppLaunchSplash({super.key, this.initialization, this.child});

  /// When supplied, the splash hands off to [child] after initialization.
  /// Leaving it null keeps this widget useful as a standalone splash in tests.
  final Future<void>? initialization;
  final Widget? child;

  @override
  State<AppLaunchSplash> createState() => _AppLaunchSplashState();
}

class _AppLaunchSplashState extends State<AppLaunchSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _showApp = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    widget.initialization?.then((_) {
      if (mounted) {
        setState(() => _showApp = true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final bool dark = brightness == Brightness.dark;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: dark ? Colors.black : Colors.white,
      ),
      home: Scaffold(body: _buildContent(dark)),
    );
  }

  Widget _buildContent(bool dark) {
    final Widget splash = Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final double value = Curves.easeInOut.transform(_controller.value);
          return Opacity(
            opacity: 0.78 + value * 0.22,
            child: Transform.scale(scale: 0.97 + value * 0.03, child: child),
          );
        },
        child: Text(
          'JHenTai',
          style: TextStyle(
            color: dark ? Colors.white : Colors.black,
            fontSize: 42,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
    if (widget.child == null) {
      return splash;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 650),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final Animation<double> scale = Tween<double>(
          begin: 1.035,
          end: 1,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<String>(_showApp ? 'app' : 'splash'),
        child: _showApp ? widget.child! : splash,
      ),
    );
  }
}
