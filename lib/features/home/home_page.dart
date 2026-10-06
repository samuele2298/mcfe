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
        const _PlanCard(),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, c) => Wrap(spacing: 8, runSpacing: 8, children: [
          for (final a in homeActions)
            SizedBox(
              // telefono: due card per riga
              width: c.maxWidth < 560 ? (c.maxWidth - 8) / 2 : 250,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.go(a.$4),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(a.$1, size: 32, color: t.colorScheme.primary),
                      const SizedBox(height: 8),
                      Text(a.$2, style: t.textTheme.titleMedium),
                      Text(a.$3, style: t.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                ),
              ),
            ),
        ])),
      ]),
    );
  }
}

final planProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) async => await ref.read(apiProvider).get('/me/plan') as Map<String, dynamic>,
);

/// Piano della settimana: le attività di oggi e, a richiesta, quelle dei giorni successivi.
class _PlanCard extends ConsumerWidget {
  const _PlanCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider).value;
    if (plan == null) return const SizedBox.shrink();
    final t = Theme.of(context);
    final days = (plan['days'] as List).cast<Map<String, dynamic>>();
    final focus = (plan['focus'] as List).cast<String>();
    Widget taskTile(Map<String, dynamic> task) => ListTile(
          dense: true,
          leading: const Icon(Icons.check_box_outline_blank, size: 20),
          title: Text(task['label'] as String),
          subtitle: Text(task['detail'] as String),
          onTap: () => context.go(task['link'] as String),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Piano di oggi', style: t.textTheme.titleMedium),
          ),
          if (focus.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Focus della settimana: ${focus.join(', ')}', style: t.textTheme.bodySmall),
            ),
          for (final task in (days.first['tasks'] as List).cast<Map<String, dynamic>>()) taskTile(task),
          ExpansionTile(
            title: const Text('Resto della settimana'),
            children: [
              for (final d in days.skip(1)) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(d['weekday'] as String, style: t.textTheme.labelLarge),
                ),
                for (final task in (d['tasks'] as List).cast<Map<String, dynamic>>()) taskTile(task),
              ],
            ],
          ),
        ]),
      ),
    );
  }
}

const homeActions = <(IconData, String, String, String)>[
  (Icons.extension, 'Puzzle', 'Per tema, punti deboli o ripasso', '/puzzles'),
  (Icons.bolt, 'Storm', '3 minuti di tattica a tempo', '/storm'),
  (Icons.sports_esports, 'Gioca', 'Contro il computer, con analisi', '/play'),
  (Icons.menu_book, 'Aperture', 'Esplora, salva e ripassa il repertorio', '/openings'),
  (Icons.manage_search, 'Analisi e coach', 'Motore, fatti e spiegazioni', '/analysis'),
  (Icons.insights, 'Statistiche', 'Rating e punti deboli', '/stats'),
];
