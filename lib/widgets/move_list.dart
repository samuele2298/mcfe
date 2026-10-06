import 'package:flutter/material.dart';

/// Lista mosse in SAN, numerata; la mossa selezionata è evidenziata e cliccabile.
class MoveList extends StatelessWidget {
  const MoveList({
    super.key,
    required this.sans,
    this.startWhite = true,
    this.startMove = 1,
    this.selected,
    this.onSelect,
    this.annotations = const {},
  });

  final List<String> sans;
  final bool startWhite;
  final int startMove;

  /// indice (0-based) della mossa selezionata
  final int? selected;
  final void Function(int index)? onSelect;

  /// simboli per indice di mossa, es. {4: '??'}
  final Map<int, String> annotations;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final chips = <Widget>[];
    var moveNo = startMove;
    var white = startWhite;
    for (var i = 0; i < sans.length; i++) {
      if (white || i == 0) {
        chips.add(Padding(
          padding: const EdgeInsets.only(left: 4, right: 2),
          child: Text(white ? '$moveNo.' : '$moveNo...', style: t.textTheme.bodySmall),
        ));
      }
      final ann = annotations[i];
      final color = switch (ann) {
        '??' => t.colorScheme.error,
        '?' => Colors.orange,
        '?!' => Colors.amber.shade700,
        _ => null,
      };
      chips.add(InkWell(
        onTap: onSelect == null ? null : () => onSelect!(i),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: selected == i ? t.colorScheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text('${sans[i]}${ann ?? ''}', style: TextStyle(color: color, fontWeight: ann != null ? FontWeight.bold : null)),
        ),
      ));
      if (!white) moveNo++;
      white = !white;
    }
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 4, children: chips);
  }
}
