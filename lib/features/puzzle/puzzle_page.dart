import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/client.dart';
import '../../api/models.dart';
import '../../chess/chess_utils.dart';
import '../../chess/puzzle_runner.dart';
import '../../state/providers.dart';
import '../../widgets/board.dart';
import '../../widgets/common.dart';
import '../coach/coach_panel.dart';

/// Allenamento puzzle: mix, per tema, punti deboli, ripasso.
class PuzzlePage extends ConsumerStatefulWidget {
  const PuzzlePage({super.key, this.initialMode, this.initialTheme, this.puzzleId});
  final String? initialMode;
  final String? initialTheme;
  final String? puzzleId;

  @override
  ConsumerState<PuzzlePage> createState() => _PuzzlePageState();
}

class _PuzzlePageState extends ConsumerState<PuzzlePage> {
  late String _mode = widget.initialMode ?? 'mix';
  late String? _theme = widget.initialTheme;
  PuzzleRunner? _runner;
  Object? _error;
  bool _loading = false;
  int _reviewDue = 0;
  String? _hintUci;
  bool _reported = false;
  ({int before, int after, List<StatChange> changes})? _result;
  final List<String> _recent = [];

  @override
  void initState() {
    super.initState();
    _load(id: widget.puzzleId);
  }

  @override
  void dispose() {
    _runner?.dispose();
    super.dispose();
  }

  Future<void> _load({String? id}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiProvider);
      Puzzle puzzle;
      if (id != null) {
        puzzle = Puzzle.fromJson(await api.get('/puzzles/$id') as Map<String, dynamic>);
      } else {
        final res = await api.get('/puzzles/next', query: {
          'mode': _mode,
          'theme': _mode == 'theme' ? _theme : null,
          'exclude': _recent.join(','),
        }) as Map<String, dynamic>;
        puzzle = Puzzle.fromJson(res['puzzle'] as Map<String, dynamic>);
        _reviewDue = res['reviewDue'] as int;
      }
      _recent.add(puzzle.id);
      if (_recent.length > 30) _recent.removeAt(0);
      _runner?.dispose();
      setState(() {
        _runner = PuzzleRunner(puzzle)..addListener(_onRunnerChange);
        _hintUci = null;
        _reported = false;
        _result = null;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.code == 'no_puzzle'
          ? (_mode == 'review' ? 'Nessun puzzle da ripassare: ottimo!' : 'Nessun puzzle trovato')
          : e);
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onRunnerChange() {
    final r = _runner!;
    if (r.finished && !_reported) {
      _reported = true;
      _report(r);
    }
    setState(() {});
  }

  Future<void> _report(PuzzleRunner r) async {
    final solved = r.status == PuzzleStatus.solved && !r.failedOnce && !r.hintUsed;
    try {
      final res = await ref.read(apiProvider).post('/puzzles/${r.puzzle.id}/attempt', {
        'solved': solved,
        'timeMs': r.elapsedMs,
        'mode': _mode == 'weakness' ? 'theme' : _mode,
      }) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _result = (
            before: res['ratingBefore'] as int,
            after: res['ratingAfter'] as int,
            changes: (res['changes'] as List).map((e) => StatChange.fromJson(e as Map<String, dynamic>)).toList(),
          ));
    } catch (_) {}
  }

  void _setMode(String mode, {String? theme}) {
    setState(() {
      _mode = mode;
      _theme = theme;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ModeBar(
            mode: _mode,
            theme: _theme,
            reviewDue: _reviewDue,
            onChanged: _setMode,
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return ErrorView(_error!, onRetry: _load);
    }
    final r = _runner;
    if (r == null) return const Center(child: CircularProgressIndicator());
    return BoardLayout(
      board: ChessBoardView(
        position: r.position,
        whiteBottom: r.userWhite,
        lastMove: r.lastMove,
        interactive: r.status == PuzzleStatus.playing,
        playerWhite: r.userWhite,
        onMove: r.userMove,
        arrows: [
          if (_hintUci != null && r.status == PuzzleStatus.playing) goodArrow(_hintUci!),
          if (r.wrongMove != null) badArrow(r.wrongMove!),
        ],
      ),
      panel: _Panel(
        runner: r,
        result: _result,
        loading: _loading,
        onNext: () => _load(),
        onHint: () => setState(() => _hintUci = r.hint()),
        onRetry: r.retry,
        onSolution: r.showSolution,
      ),
    );
  }
}

class _ModeBar extends ConsumerWidget {
  const _ModeBar({required this.mode, required this.theme, required this.reviewDue, required this.onChanged});
  final String mode;
  final String? theme;
  final int reviewDue;
  final void Function(String mode, {String? theme}) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themes = ref.watch(themesProvider).value ?? const [];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ChoiceChip(label: const Text('Mix'), selected: mode == 'mix', onSelected: (_) => onChanged('mix')),
        ChoiceChip(
          label: const Text('Punti deboli'),
          avatar: const Icon(Icons.track_changes, size: 18),
          selected: mode == 'weakness',
          onSelected: (_) => onChanged('weakness'),
        ),
        ChoiceChip(
          label: Text('Ripasso${reviewDue > 0 ? ' ($reviewDue)' : ''}'),
          avatar: const Icon(Icons.replay, size: 18),
          selected: mode == 'review',
          onSelected: (_) => onChanged('review'),
        ),
        DropdownMenu<String>(
          key: ValueKey(theme),
          initialSelection: mode == 'theme' ? theme : null,
          hintText: 'Scegli un tema',
          width: 260,
          menuHeight: 400,
          enableFilter: true,
          requestFocusOnTap: true,
          dropdownMenuEntries: [
            for (final t in themes) DropdownMenuEntry(value: t.key, label: t.label),
          ],
          onSelected: (k) {
            if (k != null) onChanged('theme', theme: k);
          },
        ),
      ],
    );
  }
}

class _Panel extends ConsumerWidget {
  const _Panel({
    required this.runner,
    required this.result,
    required this.loading,
    required this.onNext,
    required this.onHint,
    required this.onRetry,
    required this.onSolution,
  });

  final PuzzleRunner runner;
  final ({int before, int after, List<StatChange> changes})? result;
  final bool loading;
  final VoidCallback onNext;
  final VoidCallback onHint;
  final VoidCallback onRetry;
  final VoidCallback onSolution;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final p = runner.puzzle;
    final labels = {for (final th in ref.watch(themesProvider).value ?? const <ThemeInfo>[]) th.key: th.label};
    final white = runner.userWhite;
    final (icon, color, title) = switch (runner.status) {
      PuzzleStatus.loading || PuzzleStatus.opponentMoving => (Icons.hourglass_top, t.colorScheme.outline, 'Attendi la mossa...'),
      PuzzleStatus.playing when runner.failedOnce => (Icons.refresh, t.colorScheme.tertiary, 'Riprova: trova la mossa giusta'),
      PuzzleStatus.playing => (Icons.psychology, t.colorScheme.primary, 'Trova la mossa migliore per ${sideName(white)}'),
      PuzzleStatus.solved when runner.failedOnce || runner.hintUsed => (Icons.check, t.colorScheme.tertiary, 'Risolto, ma con aiuto'),
      PuzzleStatus.solved => (Icons.check_circle, Colors.green, 'Corretto!'),
      PuzzleStatus.failed => (Icons.cancel, t.colorScheme.error, 'Mossa sbagliata'),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: t.textTheme.titleLarge)),
            ]),
            const SizedBox(height: 12),
            Text('Puzzle ${p.id} · rating ${p.rating}', style: t.textTheme.bodySmall),
            if (result != null) ...[
              const SizedBox(height: 8),
              _RatingDelta(before: result!.before, after: result!.after),
            ],
            if (runner.finished) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final th in p.themes)
                  if (labels[th] != null) Chip(label: Text(labels[th]!), visualDensity: VisualDensity.compact),
              ]),
              const SizedBox(height: 8),
              Text('Soluzione: ${uciLineToSan(p.fen, p.moves)}', style: t.textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (runner.status == PuzzleStatus.playing && !runner.hintUsed)
                OutlinedButton.icon(onPressed: onHint, icon: const Icon(Icons.lightbulb_outline), label: const Text('Suggerimento')),
              if (runner.status == PuzzleStatus.failed && runner.expectedUci != null) ...[
                OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.undo), label: const Text('Riprova')),
                OutlinedButton.icon(onPressed: onSolution, icon: const Icon(Icons.visibility), label: const Text('Soluzione')),
              ],
              if (runner.finished)
                FilledButton.icon(
                  onPressed: loading ? null : onNext,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Prossimo'),
                ),
              if (!runner.finished && runner.status == PuzzleStatus.playing)
                TextButton(onPressed: loading ? null : onNext, child: const Text('Salta')),
            ]),
            if (runner.finished) ...[
              const SizedBox(height: 16),
              CoachButton(fen: runner.position.fen, context: 'puzzle ${p.id}, temi: ${p.themes.join(', ')}'),
            ],
          ],
        ),
      ),
    );
  }
}

class _RatingDelta extends StatelessWidget {
  const _RatingDelta({required this.before, required this.after});
  final int before;
  final int after;

  @override
  Widget build(BuildContext context) {
    final d = after - before;
    if (before == 0 && after == 0) return const SizedBox.shrink();
    return Text(
      'Rating $after (${d >= 0 ? '+' : ''}$d)',
      style: TextStyle(fontWeight: FontWeight.bold, color: d >= 0 ? Colors.green : Theme.of(context).colorScheme.error),
    );
  }
}
