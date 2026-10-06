import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/client.dart';
import '../../api/models.dart';
import '../../chess/chess_utils.dart';
import '../../state/providers.dart';
import '../../widgets/board.dart';

/// Pulsante "Chiedi al coach": apre il pannello con la spiegazione della posizione.
class CoachButton extends StatelessWidget {
  const CoachButton({super.key, required this.fen, this.context, this.moves, this.label = 'Chiedi al coach'});
  final String fen;
  final String? context;

  /// mosse UCI dalla posizione iniziale (per riconoscere l'apertura)
  final List<String>? moves;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.school_outlined),
      label: Text(label),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        constraints: const BoxConstraints(maxWidth: 900),
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.9,
          child: CoachSheet(fen: fen, moves: moves, contextText: this.context),
        ),
      ),
    );
  }
}

class CoachSheet extends ConsumerStatefulWidget {
  const CoachSheet({super.key, required this.fen, this.moves, this.contextText});
  final String fen;
  final List<String>? moves;
  final String? contextText;

  @override
  ConsumerState<CoachSheet> createState() => _CoachSheetState();
}

class _CoachSheetState extends ConsumerState<CoachSheet> {
  final _question = TextEditingController();
  Map<String, dynamic>? _result;
  bool _loading = false;
  Object? _error;
  List<String>? _shownLine; // mosse UCI mostrate sulla mini-scacchiera
  String? _feedbackSent;

  @override
  void initState() {
    super.initState();
    _ask();
  }

  Future<void> _ask() async {
    setState(() {
      _loading = true;
      _error = null;
      _feedbackSent = null;
    });
    try {
      final r = await ref.read(apiProvider).post('/coach/explain', {
        'fen': widget.fen,
        if (widget.moves != null && widget.moves!.isNotEmpty) 'moves': widget.moves,
        if (_question.text.trim().isNotEmpty) 'question': _question.text.trim(),
        if (widget.contextText != null) 'context': widget.contextText,
      }) as Map<String, dynamic>;
      setState(() {
        _result = r;
        _shownLine = null;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.code == 'engine_unavailable' ? 'Motore non disponibile' : e.code);
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendFeedback(String kind) async {
    String? note;
    if (kind == 'wrong') {
      note = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final c = TextEditingController();
          return AlertDialog(
            title: const Text('Cosa non va nella spiegazione?'),
            content: TextField(controller: c, maxLines: 3, decoration: const InputDecoration(hintText: 'Facoltativo')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
              FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Invia')),
            ],
          );
        },
      );
      if (note == null) return;
    }
    await ref.read(apiProvider).post('/coach/${_result!['id']}/feedback', {
      'feedback': kind,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    setState(() => _feedbackSent = kind);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = _result;
    final position = Pos(widget.fen);
    var boardPos = position;
    String? lastMove;
    for (final u in _shownLine ?? const <String>[]) {
      boardPos = boardPos.play(u) ?? boardPos;
      lastMove = u;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 700;
        final board = SizedBox(
          width: wide ? 300 : double.infinity,
          height: 300,
          child: ChessBoardView(
            position: boardPos,
            whiteBottom: position.whiteToMove,
            interactive: false,
            lastMove: lastMove,
            arrows: [if (lastMove != null) goodArrow(lastMove)],
            maxSize: 300,
          ),
        );
        final content = ListView(children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _question,
                decoration: const InputDecoration(
                  hintText: 'Domanda facoltativa (es. "qual è il piano?")',
                  isDense: true,
                ),
                onSubmitted: (_) => _ask(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _loading ? null : _ask, child: const Text('Chiedi')),
          ]),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Text('Errore: $_error', style: TextStyle(color: t.colorScheme.error)),
          if (r != null && !_loading) ..._resultWidgets(t, r),
        ]);
        if (wide) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            board,
            const SizedBox(width: 16),
            Expanded(child: content),
          ]);
        }
        return Column(children: [board, const SizedBox(height: 8), Expanded(child: content)]);
      }),
    );
  }

  List<Widget> _resultWidgets(ThemeData t, Map<String, dynamic> r) {
    final sources = {for (final s in (r['sources'] as List).cast<Map<String, dynamic>>()) s['id'] as String: s};
    final lines = (r['lines'] as List).cast<Map<String, dynamic>>();
    final opening = r['opening'] as Map<String, dynamic>?;
    final tb = r['tablebase'] as Map<String, dynamic>?;
    return [
      if (r['notice'] != null)
        Card(
          color: t.colorScheme.secondaryContainer,
          child: Padding(padding: const EdgeInsets.all(12), child: Text(r['notice'] as String)),
        ),
      Text(r['concept'] as String, style: t.textTheme.titleLarge),
      if (opening != null) Text('${opening['eco']} ${opening['name']}', style: t.textTheme.bodySmall),
      const SizedBox(height: 8),
      for (final e in (r['explanation'] as List).cast<Map<String, dynamic>>())
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e['text'] as String),
            Wrap(spacing: 6, children: [
              if (e['move'] != null)
                ActionChip(
                  avatar: const Icon(Icons.play_arrow, size: 16),
                  label: Text(_moveLabel(e['move'] as Map<String, dynamic>)),
                  onPressed: () => setState(() => _shownLine = ((e['move'] as Map)['uci'] as List).cast<String>()),
                ),
              for (final id in (e['sources'] as List).cast<String>())
                if (sources[id] != null)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('${sources[id]!['heading']}${sources[id]!['verified'] == true ? '' : ' · da confermare'}',
                        style: t.textTheme.bodySmall),
                  ),
            ]),
          ]),
        ),
      if (r['plan'] != null) ...[
        Text('Piano', style: t.textTheme.titleSmall),
        Text(r['plan'] as String),
        const SizedBox(height: 8),
      ],
      if (r['missingKnowledge'] != null)
        Text('Teoria mancante: ${r['missingKnowledge']}', style: t.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
      if (r['usesUnverified'] == true)
        Text('Parte della teoria usata è ancora da confermare.', style: t.textTheme.bodySmall?.copyWith(color: Colors.orange)),
      const Divider(height: 24),
      Text('Fatti verificati', style: t.textTheme.titleSmall),
      if (tb != null) Text('Tablebase: ${tb['category']}${tb['dtz'] != null ? ' (DTZ ${tb['dtz']})' : ''}'),
      for (final (i, l) in lines.indexed)
        InkWell(
          onTap: () => setState(() => _shownLine = (l['pv'] as List).cast<String>().take(6).toList()),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('${i + 1}. [${l['evalText']}] ${(l['san'] as List).take(8).join(' ')}',
                style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
          ),
        ),
      for (final f in (r['facts'] as List).cast<String>()) Text('• $f', style: t.textTheme.bodySmall),
      const SizedBox(height: 12),
      if (_feedbackSent == null)
        Wrap(spacing: 8, children: [
          TextButton.icon(onPressed: () => _sendFeedback('useful'), icon: const Icon(Icons.thumb_up_outlined), label: const Text('Utile')),
          TextButton.icon(onPressed: () => _sendFeedback('wrong'), icon: const Icon(Icons.flag_outlined), label: const Text('Spiegazione sbagliata')),
        ])
      else
        Text('Grazie per il feedback.', style: t.textTheme.bodySmall),
    ];
  }

  String _moveLabel(Map<String, dynamic> m) {
    final uci = (m['uci'] as List).cast<String>();
    final pos = Pos(widget.fen);
    return uciLineToSan(pos.fen, uci, maxMoves: uci.length);
  }
}

String tbCategoryLabel(String c) => switch (c) {
      'win' => 'vinta',
      'loss' => 'persa',
      'draw' => 'patta',
      _ => c,
    };

/// Riepilogo compatto per le liste (usato da altre pagine).
String classificationShort(String? c) => classificationLabels[c] ?? '-';
