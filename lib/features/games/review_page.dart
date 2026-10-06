import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/models.dart';
import '../../chess/chess_utils.dart';
import '../../state/providers.dart';
import '../../widgets/board.dart';
import '../../widgets/common.dart';
import '../../widgets/move_list.dart';
import '../coach/coach_panel.dart';

/// Revisione di una partita: navigazione mosse, grafico della valutazione, errori diagnosticati.
class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key, required this.gameId});
  final String gameId;

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  Map<String, dynamic>? _data;
  Object? _error;
  int _ply = 0; // 0 = posizione iniziale
  Timer? _poll;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await ref.read(apiProvider).get('/games/${widget.gameId}/review') as Map<String, dynamic>;
      final status = d['analysisStatus'] as String;
      setState(() {
        _data = d;
        final km = (d['keyMoments'] as List).cast<int>();
        if (_ply == 0 && km.isNotEmpty) _ply = km.first;
      });
      _poll?.cancel();
      if (status == 'queued' || status == 'running') {
        _poll = Timer(const Duration(seconds: 3), _load);
      }
    } catch (e) {
      setState(() => _error = e);
    }
  }

  Future<void> _reanalyze() async {
    await ref.read(apiProvider).post('/games/${widget.gameId}/analyze');
    _load();
  }

  List<String> get _ucis {
    final moves = (_data!['moves'] as List).cast<Map<String, dynamic>>();
    if (moves.isNotEmpty) return moves.map((m) => m['uci'] as String).toList();
    return (_data!['rawMoves'] as List).cast<String>();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorView(_error!, onRetry: _load);
    final d = _data;
    if (d == null) return const Center(child: CircularProgressIndicator());
    final ucis = _ucis;
    final positions = replay(d['startFen'] as String, ucis);
    final ply = _ply.clamp(0, positions.length - 1);
    final moves = (d['moves'] as List).cast<Map<String, dynamic>>();
    final current = ply > 0 && ply <= moves.length ? moves[ply - 1] : null;
    final userWhite = d['userColor'] == 'white';
    final sans = moves.isNotEmpty
        ? moves.map((m) => m['san'] as String).toList()
        : [for (var i = 0; i < ucis.length; i++) positions[i].san(ucis[i]) ?? ucis[i]];
    final annotations = <int, String>{
      for (final (i, m) in moves.indexed)
        if (m['byUser'] == true)
          if (switch (m['classification']) { 'blunder' => '??', 'mistake' => '?', 'inaccuracy' => '?!', _ => null } case final a?) i: a,
    };
    // in una posizione con errore si mostra la mossa giocata e la migliore
    final arrows = <BoardArrow>[
      if (current != null && (current['classification'] == 'mistake' || current['classification'] == 'blunder')) ...[
        badArrow(current['uci'] as String),
        if (current['bestUci'] != null) goodArrow(current['bestUci'] as String),
      ],
    ];
    final boardPos = arrows.isNotEmpty ? positions[ply - 1] : positions[ply];

    return KeyboardListener(
      focusNode: _focus..requestFocus(),
      onKeyEvent: (e) {
        if (e is! KeyDownEvent) return;
        if (e.logicalKey == LogicalKeyboardKey.arrowLeft) setState(() => _ply = (ply - 1).clamp(0, positions.length - 1));
        if (e.logicalKey == LogicalKeyboardKey.arrowRight) setState(() => _ply = (ply + 1).clamp(0, positions.length - 1));
      },
      child: PageBody(
        child: BoardLayout(
          board: ChessBoardView(
            position: boardPos,
            whiteBottom: userWhite,
            lastMove: arrows.isNotEmpty ? null : (ply > 0 ? ucis[ply - 1] : null),
            interactive: false,
            arrows: arrows,
          ),
          panel: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Header(d, onReanalyze: _reanalyze),
            const SizedBox(height: 8),
            if (moves.isNotEmpty) SizedBox(height: 110, child: _EvalChart(moves, ply, (p) => setState(() => _ply = p))),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(onPressed: () => setState(() => _ply = 0), icon: const Icon(Icons.first_page)),
              IconButton(onPressed: () => setState(() => _ply = (ply - 1).clamp(0, positions.length - 1)), icon: const Icon(Icons.chevron_left)),
              IconButton(onPressed: () => setState(() => _ply = (ply + 1).clamp(0, positions.length - 1)), icon: const Icon(Icons.chevron_right)),
              IconButton(onPressed: () => setState(() => _ply = positions.length - 1), icon: const Icon(Icons.last_page)),
            ]),
            if (current != null) _MoveInfo(current, (d['mistakes'] as List).cast<Map<String, dynamic>>(), positions[ply - 1]),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: MoveList(
                  sans: sans,
                  startWhite: positions.first.whiteToMove,
                  startMove: positions.first.fullmoves,
                  selected: ply - 1,
                  annotations: annotations,
                  onSelect: (i) => setState(() => _ply = i + 1),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.d, {required this.onReanalyze});
  final Map<String, dynamic> d;
  final VoidCallback onReanalyze;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final status = d['analysisStatus'] as String;
    final mistakes = (d['mistakes'] as List).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${d['result'] ?? ''} · ${d['opponent'] ?? ''}', style: t.textTheme.titleLarge),
          const SizedBox(height: 4),
          switch (status) {
            'done' => Text('Precisione ${d['accuracy'] ?? '-'}% · $mistakes errori gravi'),
            'queued' || 'running' => const Row(children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('Analisi in corso...'),
              ]),
            'failed' => Row(children: [
                const Text('Analisi non riuscita'),
                TextButton(onPressed: onReanalyze, child: const Text('Riprova')),
              ]),
            _ => Row(children: [
                const Text('Partita non analizzata'),
                TextButton(onPressed: onReanalyze, child: const Text('Analizza')),
              ]),
          },
        ]),
      ),
    );
  }
}

class _MoveInfo extends StatelessWidget {
  const _MoveInfo(this.m, this.mistakes, this.posBefore);
  final Map<String, dynamic> m;
  final List<Map<String, dynamic>> mistakes;
  final Pos posBefore;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cls = m['classification'] as String?;
    final mistake = mistakes.where((x) => x['ply'] == m['ply']).firstOrNull;
    final bestUci = m['bestUci'] as String?;
    final bestPv = (m['bestPv'] as List?)?.cast<String>() ?? const [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${m['san']}${m['byUser'] == true ? '' : ' (avversario)'}: ${classificationLabels[cls] ?? '-'}',
              style: t.textTheme.titleMedium),
          if (m['evalAfter'] != null) Text('Valutazione: ${formatEval(m['evalAfter'] as int)}', style: t.textTheme.bodySmall),
          if (bestUci != null && cls != 'best') ...[
            const SizedBox(height: 4),
            Text('Migliore: ${uciLineToSan(posBefore.fen, bestPv.isNotEmpty ? bestPv : [bestUci], maxMoves: 6)}'),
          ],
          if (mistake != null) ...[
            const SizedBox(height: 8),
            Text(mistake['categoryLabel'] as String, style: TextStyle(fontWeight: FontWeight.bold, color: t.colorScheme.error)),
            for (final r in (mistake['reasons'] as List).cast<String>()) Text('• $r'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (mistake['puzzleId'] != null)
                FilledButton.tonalIcon(
                  onPressed: () => context.go('/puzzles?mode=review&id=${Uri.encodeComponent(mistake['puzzleId'] as String)}'),
                  icon: const Icon(Icons.extension),
                  label: const Text('Rifallo come puzzle'),
                ),
              CoachButton(fen: posBefore.fen, context: 'errore in partita: giocato ${m['san']}'),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _EvalChart extends StatelessWidget {
  const _EvalChart(this.moves, this.ply, this.onTap);
  final List<Map<String, dynamic>> moves;
  final int ply;
  final void Function(int ply) onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    double clampEval(int? cp) => ((cp ?? 0).clamp(-1000, 1000)) / 100;
    final spots = [
      FlSpot(0, clampEval(moves.first['evalBefore'] as int?)),
      for (final m in moves) FlSpot((m['ply'] as int).toDouble(), clampEval(m['evalAfter'] as int?)),
    ];
    return LineChart(LineChartData(
      minY: -10,
      maxY: 10,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: const FlTitlesData(show: false),
      extraLinesData: ExtraLinesData(
        horizontalLines: [HorizontalLine(y: 0, color: t.colorScheme.outline, strokeWidth: 1)],
        verticalLines: [VerticalLine(x: ply.toDouble(), color: t.colorScheme.primary, strokeWidth: 1)],
      ),
      lineTouchData: LineTouchData(
        touchCallback: (event, resp) {
          if (event is FlTapUpEvent && resp?.lineBarSpots?.isNotEmpty == true) {
            onTap(resp!.lineBarSpots!.first.x.round());
          }
        },
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          color: t.colorScheme.primary,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: Colors.white.withValues(alpha: 0.6), cutOffY: 0, applyCutOffY: true),
          aboveBarData: BarAreaData(show: true, color: Colors.black.withValues(alpha: 0.4), cutOffY: 0, applyCutOffY: true),
        ),
      ],
    ));
  }
}
