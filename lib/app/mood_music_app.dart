import 'dart:async';
import '../core/widgets/launch_intro.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/presentation/auth_screen.dart';
import 'app_controller.dart';
import 'app_shell.dart';

class MoodMusicApp extends StatefulWidget {
  const MoodMusicApp({super.key, required this.controller, required this.auth});
  final AppController controller;
  final AuthRepository auth;
  @override
  State<MoodMusicApp> createState() => _MoodMusicAppState();
}
class _MoodMusicAppState extends State<MoodMusicApp> with WidgetsBindingObserver {
  bool _intro = true;
  bool _introVisible = true;
  Timer? _exitTimer;
  Timer? _timer;
  AppController get controller => widget.controller;
  AuthRepository get auth => widget.auth;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startIntro();
  }
  void _startIntro() {
    _timer?.cancel();
    _exitTimer?.cancel();
    controller.audio?.welcomeOnNextOpen = false;
    _intro = true;
    _introVisible = true;
    _timer = Timer(const Duration(milliseconds: 3600), () {
      if (!mounted) return;
      setState(() => _introVisible = false);
      _exitTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _intro = false);
      });
    });
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        controller.audio?.welcomeOnNextOpen == true && mounted) {
      setState(_startIntro);
    }
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _exitTimer?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      // Cambiar de cuenta o salir descarta las rutas abiertas de la sesión anterior.
      key: ValueKey('${controller.userId ?? "guest"}:${controller.demoOpen}:${controller.sessionError}'),
      title: 'MoodMusic', debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark), themeMode: controller.themeMode,
      builder: (context, child) => Stack(children: [
        ExcludeSemantics(excluding: _intro,
          child: IgnorePointer(ignoring: _intro, child: child ?? const SizedBox.shrink())),
        if (_intro) Positioned.fill(child: AnimatedOpacity(
          opacity: _introVisible ? 1 : 0,
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero : const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          child: const LaunchIntro(),
        )),
      ]),
      home: !controller.sessionReady
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : controller.sessionError
            ? const Scaffold(body: Center(child: Padding(padding: EdgeInsets.all(24),
                child: Text('No se pudo recuperar la sesión. Cierra y vuelve a abrir la aplicación.'))))
            : controller.isSignedIn || controller.demoOpen
              ? AppShell(controller: controller)
              : AuthScreen(controller: controller, repository: auth),
    ),
  );
}
