import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/client.dart';
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
              OutlinedButton.icon(
                onPressed: () => showDialog<void>(context: context, builder: (_) => const ImportDialog()).then((_) => ref.invalidate(gamesProvider)),
                icon: const Icon(Icons.download),
                label: const Text('Importa'),
              ),
              const SizedBox(width: 8),
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


/// Import delle partite da Lichess o Chess.com: vengono analizzate in background.
class ImportDialog extends ConsumerStatefulWidget {
  const ImportDialog({super.key});

  @override
  ConsumerState<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<ImportDialog> {
  String _source = 'lichess';
  late final _user = TextEditingController(
    text: ref.read(authProvider).value?.lichessUsername ?? '',
  );
  double _max = 20;
  bool _busy = false;
  String? _message;

  void _setSource(String s) {
    final u = ref.read(authProvider).value;
    setState(() {
      _source = s;
      _user.text = (s == 'lichess' ? u?.lichessUsername : u?.chesscomUsername) ?? _user.text;
    });
  }

  Future<void> _import() async {
    if (_user.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final r = await ref.read(apiProvider).post('/games/import', {
        'source': _source,
        'username': _user.text.trim(),
        'max': _max.round(),
      }) as Map<String, dynamic>;
      await ref.read(authProvider.notifier).refreshUser();
      setState(() => _message = '${r['inserted']} partite nuove (su ${r['fetched']} trovate): l\'analisi è in corso.');
    } on ApiException catch (e) {
      setState(() => _message = switch (e.code) {
            'user_not_found' => 'Utente non trovato',
            'rate_limited' => 'Troppe richieste a Lichess: riprova tra qualche minuto',
            _ => 'Errore: ${e.code}',
          });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Importa le tue partite'),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'lichess', label: Text('Lichess')),
              ButtonSegment(value: 'chesscom', label: Text('Chess.com')),
            ],
            selected: {_source},
            onSelectionChanged: (s) => _setSource(s.first),
          ),
          const SizedBox(height: 12),
          TextField(controller: _user, decoration: const InputDecoration(labelText: 'Nome utente')),
          const SizedBox(height: 12),
          Text('Ultime ${_max.round()} partite'),
          Slider(value: _max, min: 5, max: 100, divisions: 19, onChanged: (v) => setState(() => _max = v)),
          const Text('Le partite reali mostrano le tue debolezze meglio di quelle contro il computer.',
              style: TextStyle(fontSize: 12)),
          if (_message != null) ...[const SizedBox(height: 8), Text(_message!)],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi')),
        FilledButton(onPressed: _busy ? null : _import, child: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Importa')),
      ],
    );
  }
}
