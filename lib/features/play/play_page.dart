import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/client.dart';
import '../../api/models.dart';
import '../../chess/chess_utils.dart';
import '../../state/providers.dart';
import '../../widgets/board.dart';
import '../../widgets/common.dart';
import '../../widgets/move_list.dart';
import '../coach/coach_panel.dart';

/// Partita contro il computer: normale (analisi a fine partita) o allenamento (feedback a ogni mossa).
class PlayPage extends ConsumerStatefulWidget {
  const PlayPage({super.key, this.gameId});
  final String? gameId;

  @override
  ConsumerState<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends ConsumerState<PlayPage> {
  GameState? _game;
  MoveFeedback? _feedback;
  bool _busy = false;
  Object? _error;
  String? _optimisticFen;
  String? _optimisticMove;

  // impostazioni nuova partita
  String _color = 'white';
  double _elo = 1200;
  String _mode = 'normal';

  @override
  void initState() {
    super.initState();
    if (widget.gameId != null) _load(widget.gameId!);
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await f();
    } on ApiException catch (e) {
      setState(() => _error = e.code == 'engine_unavailable' ? 'Motore non disponibile' : e.code);
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _optimisticFen = null;
          _optimisticMove = null;
        });
      }
    }
  }

  Future<void> _load(String id) => _run(() async {
        final g = GameState.fromJson(await ref.read(apiProvider).get('/play/$id') as Map<String, dynamic>);
        setState(() => _game = g);
      });

  Future<void> _start() => _run(() async {
        final g = GameState.fromJson(await ref.read(apiProvider).post('/play/start', {
          'color': _color,
          'elo': _elo.round(),
          'mode': _mode,
        }) as Map<String, dynamic>);
        setState(() {
          _game = g;
          _feedback = null;
        });
        if (mounted) context.go('/play/${g.id}');
      });

  Future<void> _move(String uci) async {
    final g = _game!;
    // mostra subito la mossa dell'utente mentre il server risponde
    setState(() {
      _optimisticFen = Pos(g.fen).play(uci)?.fen;
      _optimisticMove = uci;
    });
    await _run(() async {
      final res = await ref.read(apiProvider).post('/play/${g.id}/move', {'uci': uci}) as Map<String, dynamic>;
      setState(() {
        _game = GameState.fromJson(res['state'] as Map<String, dynamic>);
        _feedback = res['feedback'] == null ? null : MoveFeedback.fromJson(res['feedback'] as Map<String, dynamic>);
      });
    });
  }

  Future<void> _action(String action) => _run(() async {
        final g = GameState.fromJson(await ref.read(apiProvider).post('/play/${_game!.id}/$action') as Map<String, dynamic>);
        setState(() {
          _game = g;
          if (action != 'resign') _feedback = null;
        });
      });

  @override
  Widget build(BuildContext context) {
    final g = _game;
    if (g == null) {
      return PageBody(child: _busy ? const Center(child: CircularProgressIndicator()) : _setup(context));
    }
    final pos = Pos(_optimisticFen ?? g.fen);
    final lastMove = _optimisticMove ?? (g.moves.isEmpty ? null : g.moves.last);
    final fb = _feedback;
    return PageBody(
      child: BoardLayout(
        board: ChessBoardView(
          position: pos,
          whiteBottom: g.userWhite,
          lastMove: lastMove,
          interactive: g.userToMove && !_busy,
          playerWhite: g.userWhite,
          onMove: _move,
          arrows: [
            if (fb != null && fb.isBad && fb.bestUci != null && g.awaitingDecision) goodArrow(fb.bestUci!),
          ],
        ),
        panel: _panel(context, g, fb),
      ),
    );
  }

  Widget _setup(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Gioca contro il computer', style: t.textTheme.headlineSmall),
              const SizedBox(height: 16),
              const Text('Colore'),
              const SizedBox(height: 4),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'white', label: Text('Bianco')),
                  ButtonSegment(value: 'random', label: Text('Casuale')),
                  ButtonSegment(value: 'black', label: Text('Nero')),
                ],
                selected: {_color},
                onSelectionChanged: (s) => setState(() => _color = s.first),
              ),
              const SizedBox(height: 16),
              Text('Forza del computer: ${_elo.round()} Elo'),
              Slider(value: _elo, min: 600, max: 2800, divisions: 22, label: '${_elo.round()}', onChanged: (v) => setState(() => _elo = v)),
              const SizedBox(height: 8),
              const Text('Modalità'),
              const SizedBox(height: 4),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'normal', label: Text('Partita'), icon: Icon(Icons.sports_esports)),
                  ButtonSegment(value: 'training', label: Text('Allenamento'), icon: Icon(Icons.school)),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 8),
              Text(
                _mode == 'training'
                    ? 'Dopo ogni mossa vedi subito se era un errore e puoi riprovare.'
                    : 'Nessun aiuto durante la partita: alla fine trovi l\'analisi completa.',
                style: t.textTheme.bodySmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text('$_error', style: TextStyle(color: t.colorScheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(onPressed: _start, icon: const Icon(Icons.play_arrow), label: const Text('Inizia')),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _panel(BuildContext context, GameState g, MoveFeedback? fb) {
    final t = Theme.of(context);
    final status = g.finished
        ? _resultText(g)
        : g.awaitingDecision
            ? 'Errore: riprova o continua'
            : g.userToMove
                ? 'Tocca a te'
                : 'Il computer pensa...';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: Text(status, style: t.textTheme.titleLarge)),
            if (_busy) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
          const SizedBox(height: 4),
          Text(
            '${g.mode == 'training' ? 'Allenamento' : g.mode == 'adaptive' ? 'Adattiva' : 'Partita'} · Stockfish ${g.opponentElo ?? ''}'
            '${g.adaptiveTarget != null ? ' · obiettivo: ${g.adaptiveTarget}' : ''}',
            style: t.textTheme.bodySmall,
          ),
          if (_error != null) Text('$_error', style: TextStyle(color: t.colorScheme.error)),
          const Divider(height: 24),
          if (fb != null) _FeedbackCard(fb),
          if (g.awaitingDecision) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              FilledButton.icon(onPressed: _busy ? null : () => _action('takeback'), icon: const Icon(Icons.undo), label: const Text('Riprova')),
              OutlinedButton.icon(onPressed: _busy ? null : () => _action('continue'), icon: const Icon(Icons.arrow_forward), label: const Text('Continua')),
            ]),
            const SizedBox(height: 8),
            CoachButton(fen: Pos(g.fen).fen, moves: g.moves, context: 'errore in partita: ${fb?.san}'),
          ],
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: MoveList(
                sans: g.sans,
                startWhite: Pos(g.startFen).whiteToMove,
                startMove: Pos(g.startFen).fullmoves,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (!g.finished)
              OutlinedButton.icon(onPressed: _busy ? null : () => _action('resign'), icon: const Icon(Icons.flag), label: const Text('Abbandona')),
            if (g.finished) ...[
              FilledButton.icon(
                onPressed: () => context.go('/games/${g.id}'),
                icon: const Icon(Icons.analytics),
                label: const Text('Vedi analisi'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _game = null;
                    _feedback = null;
                  });
                  context.go('/play');
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Nuova partita'),
              ),
            ],
          ]),
        ]),
      ),
    );
  }

  String _resultText(GameState g) {
    final why = switch (g.termination) {
      'checkmate' => 'scacco matto',
      'resign' => 'abbandono',
      'stalemate' => 'stallo',
      'threefold_repetition' => 'ripetizione',
      'insufficient_material' => 'materiale insufficiente',
      'fifty_moves' => 'regola delle 50 mosse',
      _ => g.termination ?? '',
    };
    final s = g.userScore;
    final head = s == 1 ? 'Hai vinto' : s == 0 ? 'Hai perso' : 'Patta';
    return '$head ($why)';
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard(this.fb);
  final MoveFeedback fb;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = switch (fb.classification) {
      'blunder' => t.colorScheme.error,
      'mistake' => Colors.orange,
      'inaccuracy' => Colors.amber.shade700,
      _ => Colors.green,
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(fb.isBad ? Icons.warning_amber : Icons.check_circle, color: color),
        const SizedBox(width: 8),
        Text('${fb.san}: ${classificationLabels[fb.classification] ?? fb.classification}',
            style: t.textTheme.titleMedium?.copyWith(color: color)),
      ]),
      Text('Valutazione: prima ${formatEval(fb.evalBefore)}, dopo ${formatEval(fb.evalAfter)}', style: t.textTheme.bodySmall),
      if (fb.bestSan != null && fb.classification != 'best') Text('Mossa migliore: ${fb.bestSan}'),
      if (fb.diagnosis != null) ...[
        const SizedBox(height: 6),
        Text(mistakeLabels[fb.diagnosis!.category] ?? fb.diagnosis!.category, style: const TextStyle(fontWeight: FontWeight.bold)),
        for (final r in fb.diagnosis!.reasons) Text('• $r'),
      ],
    ]);
  }
}
