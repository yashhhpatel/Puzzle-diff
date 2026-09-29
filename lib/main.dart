import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/loading_screen.dart';
import 'services.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const DiamondPuzzleApp());
}

class DiamondPuzzleApp extends StatefulWidget {
  const DiamondPuzzleApp({super.key});
  @override
  State<DiamondPuzzleApp> createState() => _DiamondPuzzleAppState();
}

class _DiamondPuzzleAppState extends State<DiamondPuzzleApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      Sfx.I.updateMusic();
    } else if (state == AppLifecycleState.paused) {
      Sfx.I.pauseMusic();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Diamond Picture Puzzle',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: kBodyFont, scaffoldBackgroundColor: AppColors.gameBg),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: child!,
        ),
        home: const LoadingScreen(),
      );
}
