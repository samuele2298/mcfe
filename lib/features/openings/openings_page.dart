import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chess/chess_utils.dart';
import '../../state/providers.dart';
import '../../widgets/board.dart';
import '../../widgets/common.dart';
import '../../widgets/move_list.dart';

final repertoireProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ((await ref.read(apiProvider).get('/repertoire')) as List).cast<Map<String, dynamic>>();
});

/// Aperture: esplorazione dell'albero, repertorio personale, allenamento delle linee (SRS).
class OpeningsPage extends ConsumerStatefulWidget {
  const OpeningsPage({super.key});

  @override
  ConsumerState<OpeningsPage> createState() => _OpeningsPageState();
}

class _OpeningsPageState extends ConsumerState<OpeningsPage> {
  Map<String, dynamic>? _drillLine;

  @override
  Widget build(BuildContext context) {
    if (_drillLine != null) {
      return DrillView(line: _drillLine!, onDone: () => setState(() => _drillLine = null));
    }
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        const TabBar(tabs: [Tab(text: 'Esplora'), Tab(text: 'Repertorio')]),
        Expanded(
          child: TabBarView(children: [
            const ExploreView(),
            _RepertoireList(onDrill: (l) => setState(() => _drillLine = l)),
          ]),
        ),
      ]),
    );
  }
}

class ExploreView extends ConsumerStatefulWidget {
  const ExploreView({super.key});

  @override
  ConsumerState<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends ConsumerState<ExploreView> {
  final List<String> _moves = [];
  Map<String, dynamic>? _node;
  bool _whiteBottom = true;
  String _source = 'lichess';
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(apiProvider).post('/openings/tree', {'moves': _moves, 'source': _source}) as Map<String, dynamic>;
      setState(() {
        _node = r;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  void _play(String uci) {
    setState(() => _moves.add(uci));
    _load();
  }

  Future<void> _save() async {
    final name = TextEditingController(text: (_node?['opening'] as Map?)?['name'] as String? ?? '');
    var color = _whiteBottom ? 'white' : 'black';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Salva nel repertorio'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome della linea')),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'white', label: Text('Col Bianco')), ButtonSegment(value: 'black', label: Text('Col Nero'))],
              selected: {color},
              onSelectionChanged: (s) => set(() => color = s.first),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salva')),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    await ref.read(apiProvider).post('/repertoire', {'name': name.text.trim(), 'color': color, 'moves': _moves});
    ref.invalidate(repertoireProvider);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Linea salvata nel repertorio')));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final n = _node;
    final positions = replay(Pos.initial.fen, _moves);
    final pos = positions.last;
    final explorer = n?['explorer'] as Map<String, dynamic>?;
    final book = (n?['book'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    return PageBody(
      child: BoardLayout(
        board: ChessBoardView(
          position: pos,
          whiteBottom: _whiteBottom,
          lastMove: _moves.isEmpty ? null : _moves.last,
          onMove: _play,
        ),
        panel: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  n?['opening'] == null ? 'Posizione iniziale' : '${n!['opening']['eco']} ${n['opening']['name']}',
                  style: t.textTheme.titleMedium,
                ),
                if (_moves.isNotEmpty)
                  MoveList(sans: [for (var i = 0; i < _moves.length; i++) positions[i].san(_moves[i]) ?? _moves[i]]),
                Row(children: [
                  IconButton(
                    tooltip: 'Indietro',
                    onPressed: _moves.isEmpty ? null : () { setState(_moves.removeLast); _load(); },
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(tooltip: 'Gira', onPressed: () => setState(() => _whiteBottom = !_whiteBottom), icon: const Icon(Icons.swap_vert)),
                  IconButton(
                    tooltip: 'Ricomincia',
                    onPressed: () { setState(_moves.clear); _load(); },
                    icon: const Icon(Icons.restart_alt),
                  ),
                  const Spacer(),
                  if (_moves.isNotEmpty) FilledButton.tonalIcon(onPressed: _save, icon: const Icon(Icons.bookmark_add), label: const Text('Salva linea')),
                ]),
              ]),
            ),
          ),
          if (_error != null) Text('Errore: $_error', style: TextStyle(color: t.colorScheme.error)),
          if (explorer != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('Explorer', style: t.textTheme.titleSmall),
                    const Spacer(),
                    DropdownButton<String>(
                      value: _source,
                      items: const [
                        DropdownMenuItem(value: 'lichess', child: Text('Lichess')),
                        DropdownMenuItem(value: 'masters', child: Text('Maestri')),
                      ],
                      onChanged: (v) { setState(() => _source = v!); _load(); },
                    ),
                  ]),
                  for (final m in (explorer['moves'] as List).cast<Map<String, dynamic>>()) _ExplorerRow(m, onTap: () => _play(m['uci'] as String)),
                ]),
              ),
            )
          else if (n != null && n['explorerError'] != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  n['explorerError'] == 'explorer_requires_token'
                      ? 'Le statistiche di Lichess richiedono un token personale (LICHESS_TOKEN nel backend). Intanto ecco le mosse di libro.'
                      : 'Statistiche di Lichess non disponibili (${n['explorerError']}).',
                  style: t.textTheme.bodySmall,
                ),
              ),
            ),
          if (book.isNotEmpty)
            Card(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 0), child: Text('Mosse di libro', style: t.textTheme.titleSmall)),
                for (final b in book)
                  ListTile(
                    dense: true,
                    title: Text('${b['san']}'),
                    subtitle: Text('${b['eco']} ${b['name']}'),
                    onTap: () => _play(b['uci'] as String),
                  ),
              ]),
            ),
          for (final th in (n?['theory'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[])
            Card(
              child: ExpansionTile(
                title: Text(th['heading'] as String),
                subtitle: Text('${th['docTitle']}${th['verified'] == true ? '' : ' · da confermare'}'),
                children: [Padding(padding: const EdgeInsets.all(12), child: Text(th['content'] as String))],
              ),
            ),
        ]),
      ),
    );
  }
}

class _ExplorerRow extends StatelessWidget {
  const _ExplorerRow(this.m, {required this.onTap});
  final Map<String, dynamic> m;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = m['white'] as int, d = m['draws'] as int, b = m['black'] as int;
    final total = w + d + b;
    if (total == 0) return const SizedBox.shrink();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 60, child: Text(m['san'] as String, style: const TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(width: 70, child: Text('$total')),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Row(children: [
                Expanded(flex: w, child: Container(height: 12, color: Colors.white)),
                Expanded(flex: d, child: Container(height: 12, color: Colors.grey)),
                Expanded(flex: b, child: Container(height: 12, color: Colors.black)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _RepertoireList extends ConsumerWidget {
  const _RepertoireList({required this.onDrill});
  final void Function(Map<String, dynamic>) onDrill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(repertoireProvider);
    return PageBody(
      child: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(e),
        data: (lines) => lines.isEmpty
            ? const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nessuna linea: esplora le aperture e salva quelle che giochi.'),
                ),
              )
            : ListView(children: [
                for (final l in lines)
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.circle, color: l['color'] == 'white' ? Colors.white : Colors.black, shadows: const [Shadow(blurRadius: 2)]),
                      title: Text(l['name'] as String),
                      subtitle: Text(_numbered((l['sans'] as List).cast<String>())),
                      trailing: Wrap(spacing: 4, children: [
                        if (l['due'] == true) const Chip(label: Text('da ripassare'), visualDensity: VisualDensity.compact),
                        IconButton(tooltip: 'Allenati', onPressed: () => onDrill(l), icon: const Icon(Icons.fitness_center)),
                        IconButton(
                          tooltip: 'Elimina',
                          onPressed: () async {
                            await ref.read(apiProvider).delete('/repertoire/${l['id']}');
                            ref.invalidate(repertoireProvider);
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ]),
                    ),
                  ),
              ]),
      ),
    );
  }

  String _numbered(List<String> sans) =>
      [for (var i = 0; i < sans.length; i++) i.isEven ? '${i ~/ 2 + 1}. ${sans[i]}' : sans[i]].join(' ');
}

/// Allenamento di una linea: l'utente gioca le sue mosse, l'app risponde con quelle avversarie.
class DrillView extends ConsumerStatefulWidget {
  const DrillView({super.key, required this.line, required this.onDone});
  final Map<String, dynamic> line;
  final VoidCallback onDone;

  @override
  ConsumerState<DrillView> createState() => _DrillViewState();
}

class _DrillViewState extends ConsumerState<DrillView> {
  late final List<String> _line = (widget.line['moves'] as List).cast<String>();
  late final bool _white = widget.line['color'] == 'white';
  int _ply = 0;
  int _errors = 0;
  String? _wrong;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _autoPlay();
  }

  bool get _userTurn => (_ply.isEven) == _white;
  bool get _done => _ply >= _line.length;

  void _autoPlay() {
    if (_done || _userTurn) return;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _ply++);
      _autoPlay();
      _finishIfDone();
    });
  }

  void _onMove(String uci) {
    if (_done || !_userTurn) return;
    final pos = replay(Pos.initial.fen, _line.take(_ply).toList()).last;
    // stessa mossa anche se l'arrocco è scritto diversamente: si confronta la SAN
    if (pos.san(uci) == pos.san(_line[_ply])) {
      setState(() {
        _ply++;
        _wrong = null;
      });
      _autoPlay();
      _finishIfDone();
    } else {
      setState(() {
        _errors++;
        _wrong = uci;
      });
    }
  }

  Future<void> _finishIfDone() async {
    if (!_done || _sent) return;
    _sent = true;
    await ref.read(apiProvider).post('/repertoire/${widget.line['id']}/review', {'success': _errors == 0});
    ref.invalidate(repertoireProvider);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final positions = replay(Pos.initial.fen, _line.take(_ply).toList());
    return PageBody(
      child: BoardLayout(
        board: ChessBoardView(
          position: positions.last,
          whiteBottom: _white,
          lastMove: _ply > 0 ? _line[_ply - 1] : null,
          interactive: !_done && _userTurn,
          playerWhite: _white,
          onMove: _onMove,
          arrows: [
            if (_wrong != null) badArrow(_wrong!),
            if (_errors > 0 && _wrong != null && !_done) goodArrow(_line[_ply]),
          ],
        ),
        panel: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(widget.line['name'] as String, style: t.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(_done
                  ? (_errors == 0 ? 'Linea completata senza errori!' : 'Linea completata con $_errors errori: tornerà presto in ripasso.')
                  : _userTurn
                      ? (_wrong != null ? 'Non è la mossa del repertorio: la freccia verde mostra quella giusta.' : 'Gioca la mossa del tuo repertorio')
                      : 'L\'avversario risponde...'),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _line.isEmpty ? 1 : _ply / _line.length),
              const SizedBox(height: 16),
              Wrap(spacing: 8, children: [
                OutlinedButton(onPressed: widget.onDone, child: Text(_done ? 'Torna al repertorio' : 'Esci')),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
