import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';
import '../../chess/puzzle_runner.dart';
import '../../state/providers.dart';
import '../../widgets/board.dart';
import '../../widgets/common.dart';

const _duration = Duration(minutes: 3);
const _errorPenalty = Duration(seconds: 10);

/// Bonus di tempo alle soglie di combo (come Lichess Storm).
Duration _comboBonus(int combo) => switch (combo) {
      5 => const Duration(seconds: 3),
      12 => const Duration(seconds: 5),
      20 => const Duration(seconds: 7),
      30 => const Duration(seconds: 10),
      _ when combo > 30 && combo % 10 == 0 => const Duration(seconds: 10),
      _ => Duration.zero,
    };

enum _Phase { intro, loading, running, finished }

class StormPage extends ConsumerStatefulWidget {
  const StormPage({super.key});

  @override
  ConsumerState<StormPage> createState() => _StormPageState();
}

class _StormPageState extends ConsumerState<StormPage> {
  _Phase _phase = _Phase.intro;
  String? _runId;
  List<Puzzle> _puzzles = [];
  int _index = 0;
  PuzzleRunner? _runner;
  Duration _remaining = _duration;
  Timer? _ticker;
  DateTime? _startedAt;
  DateTime? _lastTick;
  int _combo = 0;
  int _bestCombo = 0;
  String? _flash;
  final List<Map<String, Object>> _results = [];
  Map<String, dynamic>? _summary;
  Object? _error;

  @override
  void dispose() {
    _ticker?.cancel();
    _runner?.dispose();
    super.dispose();
  }

  int get _solved => _results.where((r) => r['solved'] == true).length;
  int get _errors => _results.length - _solved;

  Future<void> _start() async {
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });
    try {
      final res = await ref.read(apiProvider).post('/storm/start') as Map<String, dynamic>;
      _runId = res['runId'] as String;
      _puzzles = (res['puzzles'] as List).map((e) => Puzzle.fromJson(e as Map<String, dynamic>)).toList();
      _index = 0;
      _results.clear();
      _combo = 0;
      _bestCombo = 0;
      _remaining = _duration;
      _startedAt = DateTime.now();
      _lastTick = _startedAt;
      _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
      _loadPuzzle();
      setState(() => _phase = _Phase.running);
    } catch (e) {
      setState(() {
        _error = e;
        _phase = _Phase.intro;
      });
    }
  }

  void _tick() {
    final now = DateTime.now();
    _remaining -= now.difference(_lastTick!);
    _lastTick = now;
    if (_remaining <= Duration.zero) {
      _remaining = Duration.zero;
      _finish();
    } else {
      setState(() {});
    }
  }

  void _loadPuzzle() {
    _runner?.dispose();
    if (_index >= _puzzles.length) {
      _finish();
      return;
    }
    _runner = PuzzleRunner(_puzzles[_index], opponentDelay: const Duration(milliseconds: 250))
      ..addListener(_onRunner);
  }

  void _onRunner() {
    final r = _runner!;
    if (r.status == PuzzleStatus.solved) {
      _record(r, true);
      _combo++;
      _bestCombo = _combo > _bestCombo ? _combo : _bestCombo;
      final bonus = _comboBonus(_combo);
      if (bonus > Duration.zero) {
        _remaining += bonus;
        _flash = '+${bonus.inSeconds}s';
      }
      _next();
    } else if (r.status == PuzzleStatus.failed) {
      _record(r, false);
      _combo = 0;
      _remaining -= _errorPenalty;
      _flash = '-${_errorPenalty.inSeconds}s';
      _next();
    } else {
      setState(() {});
    }
  }

  void _record(PuzzleRunner r, bool solved) {
    _results.add({'puzzleId': r.puzzle.id, 'solved': solved, 'timeMs': r.elapsedMs});
  }

  void _next() {
    _index++;
    // il listener è chiamato dentro notifyListeners del runner: si cambia puzzle al frame dopo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_phase != _Phase.running) return;
      setState(_loadPuzzle);
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _flash = null);
      });
    });
  }

  Future<void> _finish() async {
    if (_phase != _Phase.running) return;
    _ticker?.cancel();
    setState(() => _phase = _Phase.finished);
    try {
      final res = await ref.read(apiProvider).post('/storm/$_runId/finish', {
        'results': _results,
        'durationS': DateTime.now().difference(_startedAt!).inSeconds,
        'bestCombo': _bestCombo,
      }) as Map<String, dynamic>;
      if (mounted) setState(() => _summary = res);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: switch (_phase) {
        _Phase.intro => _Intro(onStart: _start, error: _error),
        _Phase.loading => const Center(child: CircularProgressIndicator()),
        _Phase.running => _buildRunning(context),
        _Phase.finished => _buildFinished(context),
      },
    );
  }

  Widget _buildRunning(BuildContext context) {
    final r = _runner;
    if (r == null) return const SizedBox.shrink();
    final t = Theme.of(context);
    final secs = _remaining.inMilliseconds / 1000;
    final clock = '${(secs ~/ 60)}:${(secs % 60).floor().toString().padLeft(2, '0')}';
    return BoardLayout(
      board: ChessBoardView(
        key: ValueKey(r.puzzle.id),
        position: r.position,
        whiteBottom: r.userWhite,
        lastMove: r.lastMove,
        interactive: r.status == PuzzleStatus.playing,
        playerWhite: r.userWhite,
        onMove: r.userMove,
      ),
      panel: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(clock, style: t.textTheme.displayMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                color: secs < 20 ? t.colorScheme.error : null,
              )),
              const SizedBox(width: 16),
              if (_flash != null)
                Text(_flash!, style: t.textTheme.headlineSmall?.copyWith(
                  color: _flash!.startsWith('+') ? Colors.green : t.colorScheme.error,
                )),
            ]),
            const SizedBox(height: 8),
            Text('Punteggio: $_solved', style: t.textTheme.headlineSmall),
            Text('Combo: $_combo  ·  Errori: $_errors'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (_combo % 10) / 10),
            const SizedBox(height: 16),
            Text('Muove ${sideName(r.userWhite)} · rating ${r.puzzle.rating}', style: t.textTheme.bodySmall),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _finish, child: const Text('Termina')),
          ]),
        ),
      ),
    );
  }

  Widget _buildFinished(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Storm finito', style: t.textTheme.headlineMedium),
            const SizedBox(height: 16),
            Text('$_solved', style: t.textTheme.displayLarge),
            const Text('puzzle risolti'),
            const SizedBox(height: 16),
            Text('Errori: $_errors · Combo migliore: $_bestCombo'),
            if (_summary != null) ...[
              const SizedBox(height: 8),
              Text(
                _summary!['score'] == _summary!['best']
                    ? 'Nuovo record personale!'
                    : 'Record: ${_summary!['best']} · posizione #${_summary!['rank']}',
                style: t.textTheme.titleMedium,
              ),
            ],
            if (_errors > 0) ...[
              const SizedBox(height: 8),
              Text('I $_errors puzzle sbagliati sono stati aggiunti al ripasso.', style: t.textTheme.bodySmall),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _start, icon: const Icon(Icons.bolt), label: const Text('Ancora')),
          ]),
        ),
      ),
    );
  }
}

class _Intro extends ConsumerWidget {
  const _Intro({required this.onStart, this.error});
  final VoidCallback onStart;
  final Object? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.bolt, size: 64, color: t.colorScheme.primary),
              Text('Puzzle Storm', style: t.textTheme.headlineMedium),
              const SizedBox(height: 12),
              const Text(
                '3 minuti, puzzle sempre più difficili. Le combo di risposte giuste danno '
                'tempo extra, ogni errore toglie 10 secondi.',
                textAlign: TextAlign.center,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text('Errore: $error', style: TextStyle(color: t.colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(onPressed: onStart, icon: const Icon(Icons.play_arrow), label: const Text('Inizia')),
            ]),
          ),
        ),
      ),
    );
  }
}
