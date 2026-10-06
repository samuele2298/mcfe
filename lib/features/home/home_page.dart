import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../stats/stats_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final stats = ref.watch(statsProvider).value;
    final weak = ref.watch(weaknessesProvider).value;
    final rating = stats?['ratingPuzzle'] as int?;
    // banner solo per debolezze con dati sufficienti e sotto il proprio rating
    final mainWeakness = weak?.where((w) => w.attempts >= 3 && (rating == null || w.rating < rating)).firstOrNull;
    final t = Theme.of(context);
    return PageBody(
      child: ListView(children: [
        Text('Ciao ${user?.name ?? ''}', style: t.textTheme.headlineMedium),
        if (stats != null)
          Text('Rating puzzle ${stats['ratingPuzzle']} · record Storm ${stats['stormBest']}',
              style: t.textTheme.titleMedium),
        const SizedBox(height: 16),
        if (mainWeakness != null)
          Card(
            color: t.colorScheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.track_changes),
              title: Text('Punto debole: ${mainWeakness.label}'),
              subtitle: const Text('Allenati sui temi in cui vai peggio'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => context.go('/puzzles?mode=weakness'),
            ),
          ),
        if (stats != null && (stats['reviewDue'] as int) > 0)
          Card(
            child: ListTile(
              leading: const Icon(Icons.replay),
              title: Text('${stats['reviewDue']} puzzle da ripassare'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => context.go('/puzzles?mode=review'),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (final a in homeActions)
            SizedBox(
              width: 250,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.go(a.$4),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(a.$1, size: 36, color: t.colorScheme.primary),
                      const SizedBox(height: 8),
                      Text(a.$2, style: t.textTheme.titleMedium),
                      Text(a.$3, style: t.textTheme.bodySmall),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

const homeActions = <(IconData, String, String, String)>[
  (Icons.extension, 'Puzzle', 'Per tema, punti deboli o ripasso', '/puzzles'),
  (Icons.bolt, 'Storm', '3 minuti di tattica a tempo', '/storm'),
  (Icons.sports_esports, 'Gioca', 'Contro il computer, con analisi', '/play'),
  (Icons.manage_search, 'Analisi e coach', 'Motore, fatti e spiegazioni', '/analysis'),
  (Icons.insights, 'Statistiche', 'Rating e punti deboli', '/stats'),
];
