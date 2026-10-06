import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';
import '../../widgets/common.dart';

final gamesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final list = await ref.read(apiProvider).get('/games') as List;
  return list.cast<Map<String, dynamic>>();
});

/// Archivio delle partite (contro il computer e importate).
class GamesPage extends ConsumerWidget {
  const GamesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final games = ref.watch(gamesProvider);
    return PageBody(
      child: games.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(e, onRetry: () => ref.invalidate(gamesProvider)),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(gamesProvider),
          child: ListView(children: [
            Row(children: [
              Expanded(child: Text('Le tue partite', style: Theme.of(context).textTheme.headlineSmall)),
              FilledButton.icon(onPressed: () => context.go('/play'), icon: const Icon(Icons.add), label: const Text('Nuova')),
            ]),
            const SizedBox(height: 12),
            if (list.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Nessuna partita ancora.'))),
            for (final g in list) _GameTile(g),
          ]),
        ),
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile(this.g);
  final Map<String, dynamic> g;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final white = g['userColor'] == 'white';
    final result = g['result'] as String?;
    final score = switch (result) {
      '1-0' => white ? 'Vinta' : 'Persa',
      '0-1' => white ? 'Persa' : 'Vinta',
      '1/2-1/2' => 'Patta',
      _ => 'In corso',
    };
    final color = switch (score) {
      'Vinta' => Colors.green,
      'Persa' => t.colorScheme.error,
      _ => t.colorScheme.outline,
    };
    final status = g['analysisStatus'] as String;
    final date = DateTime.parse(g['playedAt'] as String).toLocal();
    return Card(
      child: ListTile(
        leading: Icon(Icons.circle, color: white ? Colors.white : Colors.black, shadows: const [Shadow(blurRadius: 2)]),
        title: Text('$score · ${g['opponent'] ?? 'Avversario'}', style: TextStyle(color: color)),
        subtitle: Text([
          '${date.day}/${date.month}/${date.year}',
          '${((g['plies'] as int) + 1) ~/ 2} mosse',
          if (g['accuracy'] != null) 'precisione ${g['accuracy']}%',
          if (status == 'queued' || status == 'running') 'analisi in corso',
          if (g['source'] != 'play') '${g['source']}',
        ].join(' · ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(result == null && (g['source'] == 'play' || g['source'] == 'adaptive') ? '/play/${g['id']}' : '/games/${g['id']}'),
      ),
    );
  }
}
