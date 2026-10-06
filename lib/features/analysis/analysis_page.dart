import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/client.dart';
import '../../chess/chess_utils.dart';
import '../../state/providers.dart';
import '../../widgets/board.dart';
import '../../widgets/common.dart';
import '../../widgets/move_list.dart';
import '../coach/coach_panel.dart';

/// Analisi libera: si muovono entrambi i colori, il motore valuta, il coach spiega.
class AnalysisPage extends ConsumerStatefulWidget {
  const AnalysisPage({super.key, this.initialFen});
  final String? initialFen;

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
  late String _startFen = widget.initialFen ?? Pos.initial.fen;
  final List<String> _moves = [];
  int _cursor = 0;
  bool _whiteBottom = true;
  Map<String, dynamic>? _analysis;
  bool _loading = false;
  Object? _error;
  final _fenCtrl = TextEditingController();

  List<Pos> get _positions => replay(_startFen, _moves);
  Pos get _pos => _positions[_cursor.clamp(0, _positions.length - 1)];

  void _onMove(String uci) {
    setState(() {
      _moves.removeRange(_cursor, _moves.length);
      _moves.add(uci);
      _cursor = _moves.length;
      _analysis = null;
    });
  }

  Future<void> _analyse() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ref.read(apiProvider).post('/analysis', {'fen': _pos.fen, 'depth': 18, 'multipv': 3}) as Map<String, dynamic>;
      setState(() => _analysis = r);
    } on ApiException catch (e) {
      setState(() => _error = e.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loadFen() {
    final fen = _fenCtrl.text.trim();
    try {
      final p = Pos(fen);
      p.legalMoves; // valida
      setState(() {
        _startFen = p.fen;
        _moves.clear();
        _cursor = 0;
        _analysis = null;
        _whiteBottom = p.whiteToMove;
      });
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FEN non valida')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final positions = _positions;
    final sans = [for (var i = 0; i < _moves.length; i++) positions[i].san(_moves[i]) ?? _moves[i]];
    final a = _analysis;
    final lines = (a?['lines'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final fromStandardStart = _startFen == Pos.initial.fen;
    return PageBody(
      child: BoardLayout(
        board: ChessBoardView(
          position: _pos,
          whiteBottom: _whiteBottom,
          lastMove: _cursor > 0 ? _moves[_cursor - 1] : null,
          onMove: _onMove,
          arrows: [if (lines.isNotEmpty && (lines.first['pv'] as List).isNotEmpty) infoArrow((lines.first['pv'] as List).first as String)],
        ),
        panel: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _fenCtrl,
                      decoration: const InputDecoration(hintText: 'Incolla una FEN', isDense: true),
                      onSubmitted: (_) => _loadFen(),
                    ),
                  ),
                  IconButton(onPressed: _loadFen, icon: const Icon(Icons.upload), tooltip: 'Carica FEN'),
                  IconButton(onPressed: () => setState(() => _whiteBottom = !_whiteBottom), icon: const Icon(Icons.swap_vert), tooltip: 'Gira la scacchiera'),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  IconButton(onPressed: _cursor > 0 ? () => setState(() { _cursor--; _analysis = null; }) : null, icon: const Icon(Icons.chevron_left)),
                  IconButton(onPressed: _cursor < _moves.length ? () => setState(() { _cursor++; _analysis = null; }) : null, icon: const Icon(Icons.chevron_right)),
                  FilledButton.tonalIcon(onPressed: _loading ? null : _analyse, icon: const Icon(Icons.memory), label: const Text('Motore')),
                  const SizedBox(width: 8),
                  CoachButton(
                    key: ValueKey(_pos.fen),
                    fen: _pos.fen,
                    moves: fromStandardStart ? _moves.take(_cursor).toList() : null,
                    label: 'Coach',
                  ),
                ]),
              ]),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Text('Errore: $_error', style: TextStyle(color: t.colorScheme.error)),
          if (a != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final l in lines)
                    Text('[${_eval(l['evalWhite'] as int)}] ${uciLineToSan(_pos.fen, (l['pv'] as List).cast<String>(), maxMoves: 8)}'),
                  if (a['tablebase'] != null) Text('Tablebase: ${tbCategoryLabel((a['tablebase'] as Map)['category'] as String)}'),
                  const SizedBox(height: 6),
                  for (final f in ((a['facts'] as Map)['summary'] as List).cast<String>()) Text('• $f', style: t.textTheme.bodySmall),
                ]),
              ),
            ),
          if (sans.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: MoveList(
                  sans: sans,
                  startWhite: positions.first.whiteToMove,
                  startMove: positions.first.fullmoves,
                  selected: _cursor - 1,
                  onSelect: (i) => setState(() {
                    _cursor = i + 1;
                    _analysis = null;
                  }),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  String _eval(int cp) {
    if (cp.abs() >= 9000) return '${cp > 0 ? '' : '-'}M${10000 - cp.abs()}';
    final v = cp / 100;
    return '${v > 0 ? '+' : ''}${v.toStringAsFixed(1)}';
  }
}
