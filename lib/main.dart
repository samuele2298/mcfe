import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'widgets/board.dart';

void main() {
  runApp(const ProviderScope(child: MentorApp()));
}

class MentorApp extends ConsumerWidget {
  const MentorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // precarica i pezzi: niente scacchiera vuota al primo puzzle
    for (final c in ['w', 'b']) {
      for (final r in ['K', 'Q', 'R', 'B', 'N', 'P']) {
        precacheImage(AssetImage(pieceAsset('$c$r')), context);
      }
    }
    const seed = Color(0xFF3B6E4F);
    return MaterialApp.router(
      title: 'Chess Mentor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
