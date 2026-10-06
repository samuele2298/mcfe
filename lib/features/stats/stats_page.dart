import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

final statsProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) async => await ref.read(apiProvider).get('/me/stats') as Map<String, dynamic>,
);

final profileNoteProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final r = await ref.read(apiProvider).get('/me/profile') as Map<String, dynamic>;
  return r['note'] as Map<String, dynamic>?;
});

final weaknessesProvider = FutureProvider.autoDispose<List<Weakness>>((ref) async {
  final list = await ref.read(apiProvider).get('/me/weaknesses') as List;
  return list.map((e) => Weakness.fromJson(e as Map<String, dynamic>)).toList();
});

const dimensionLabels = {
  'theme': 'Temi tattici',
  'phase': 'Fasi di gioco',
  'mistake': 'Errori nelle partite',
  'structure': 'Strutture pedonali',
  'endgame_type': 'Tipi di finale',
  'opening': 'Aperture',
};

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final weak = ref.watch(weaknessesProvider);
    return PageBody(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(statsProvider);
          ref.invalidate(weaknessesProvider);
        },
        child: ListView(children: [
          stats.when(
            data: (s) => _StatsHeader(s),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => ErrorView(e),
          ),
          const SizedBox(height: 16),
          const _CoachNote(),
          weak.when(
            data: (w) => _WeaknessList(w),
            loading: () => const SizedBox.shrink(),
            error: (e, _) => ErrorView(e),
          ),
        ]),
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  const _StatsHeader(this.s);
  final Map<String, dynamic> s;

  @override
  Widget build(BuildContext context) {
    final history = (s['history'] as List).cast<Map<String, dynamic>>();
    final t = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, c) {
        // due tessere per riga su telefono, quattro su schermi larghi
        final w = c.maxWidth < 500 ? (c.maxWidth - 8) / 2 : 200.0;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          _Tile('Rating puzzle', '${s['ratingPuzzle']}', '± ${s['ratingRd']}', width: w),
          _Tile('Risolti', '${s['puzzlesSolved']}', 'sbagliati ${s['puzzlesFailed']}', width: w),
          _Tile('Record Storm', '${s['stormBest']}', 'puzzle in 3 minuti', width: w),
          _Tile('Da ripassare', '${s['reviewDue']}', 'ripetizione spaziata', width: w),
        ]);
      }),
      if (history.length >= 2) ...[
        const SectionTitle('Andamento rating (90 giorni)'),
        SizedBox(
          height: 220,
          child: LineChart(LineChartData(
            gridData: const FlGridData(drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(
              topTitles: AxisTitles(),
              rightTitles: AxisTitles(),
              bottomTitles: AxisTitles(),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44)),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (final (i, h) in history.indexed) FlSpot(i.toDouble(), (h['rating'] as num).toDouble()),
                ],
                isCurved: true,
                color: t.colorScheme.primary,
                barWidth: 2,
                dotData: const FlDotData(show: false),
              ),
            ],
          )),
        ),
      ],
    ]);
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.title, this.value, this.subtitle, {this.width = 200});
  final String title;
  final String value;
  final String subtitle;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.textTheme.labelLarge),
            Text(value, style: t.textTheme.headlineMedium),
            Text(subtitle, style: t.textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }
}

class _WeaknessList extends StatelessWidget {
  const _WeaknessList(this.items);
  final List<Weakness> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Risolvi qualche puzzle o gioca una partita: qui compariranno i tuoi punti deboli.'),
        ),
      );
    }
    final groups = <String, List<Weakness>>{};
    for (final w in items) {
      groups.putIfAbsent(w.dimension, () => []).add(w);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final e in groups.entries) ...[
        SectionTitle(dimensionLabels[e.key] ?? e.key),
        Card(
          child: Column(children: [
            for (final w in e.value.take(12)) _WeaknessRow(w),
          ]),
        ),
      ],
    ]);
  }
}

class _WeaknessRow extends StatelessWidget {
  const _WeaknessRow(this.w);
  final Weakness w;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final canTrain = w.dimension == 'theme' || w.dimension == 'phase';
    return ListTile(
      title: Text(w.label),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: w.successRate,
          color: w.successRate < 0.5 ? t.colorScheme.error : Colors.green,
        ),
        const SizedBox(height: 4),
        Text(w.dimension == 'mistake'
            ? '${w.attempts} volte'
            : '${(w.successRate * 100).round()}% su ${w.attempts} · rating ${w.rating}${w.confident ? '' : ' (provvisorio)'}'),
      ]),
      trailing: canTrain
          ? IconButton(
              tooltip: 'Allena questo tema',
              icon: const Icon(Icons.fitness_center),
              onPressed: () => context.go('/puzzles?mode=theme&theme=${w.key}'),
            )
          : null,
    );
  }
}


class _CoachNote extends ConsumerStatefulWidget {
  const _CoachNote();

  @override
  ConsumerState<_CoachNote> createState() => _CoachNoteState();
}

class _CoachNoteState extends ConsumerState<_CoachNote> {
  bool _busy = false;

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).post('/me/profile/refresh');
      ref.invalidate(profileNoteProvider);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = ref.watch(profileNoteProvider).value;
    final t = Theme.of(context);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.school_outlined),
        title: const Text('Nota del coach'),
        subtitle: Text(note?['content'] as String? ?? 'Ancora nessuna nota: si aggiorna ogni notte in base ai tuoi errori.',
            style: t.textTheme.bodyMedium),
        trailing: IconButton(
          tooltip: 'Aggiorna',
          onPressed: _busy ? null : _refresh,
          icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
        ),
      ),
    );
  }
}
