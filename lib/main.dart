import 'package:flutter/material.dart';

import 'state/rig_controller.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = RigController();
  await controller.init();
  runApp(PedaleiraApp(controller: controller));
}

class PedaleiraApp extends StatelessWidget {
  const PedaleiraApp({super.key, required this.controller});
  final RigController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PedalFX',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      darkTheme: buildTheme(),
      themeMode: ThemeMode.dark,
      home: HomeScreen(controller: controller),
    );
  }
}
