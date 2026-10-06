import 'package:flutter/material.dart';

/// Contenitore con larghezza massima centrata, per il layout web.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child, this.maxWidth = 1100});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    // su telefono margini stretti: ogni pixel serve alla scacchiera
    final pad = MediaQuery.sizeOf(context).width < 600 ? 8.0 : 16.0;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: EdgeInsets.all(pad), child: child),
      ),
    );
  }
}

bool isPhone(BuildContext context) => MediaQuery.sizeOf(context).width < 600;

/// Layout scacchiera + pannello: affiancati su schermi larghi, impilati su stretti.
class BoardLayout extends StatelessWidget {
  const BoardLayout({super.key, required this.board, required this.panel});
  final Widget board;
  final Widget panel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 900) {
        final boardSize = (c.maxWidth * 0.6).clamp(320.0, 640.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: boardSize, height: boardSize, child: board),
            const SizedBox(width: 24),
            Expanded(child: panel),
          ],
        );
      }
      // schermi stretti: scacchiera fissa in alto e pannello che scorre sotto
      // (niente lista che scorre sopra la scacchiera: il trascinamento dei pezzi resta affidabile)
      final boardSize = c.maxWidth.clamp(0.0, c.maxHeight.isFinite ? c.maxHeight * 0.62 : c.maxWidth);
      return Column(
        children: [
          SizedBox(width: boardSize, height: boardSize, child: board),
          const SizedBox(height: 8),
          Expanded(child: SingleChildScrollView(child: panel)),
        ],
      );
    });
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView(this.error, {super.key, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 40),
        const SizedBox(height: 8),
        Text('Errore: $error', textAlign: TextAlign.center),
        if (onRetry != null) ...[
          const SizedBox(height: 8),
          FilledButton(onPressed: onRetry, child: const Text('Riprova')),
        ],
      ]),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

String sideName(bool white) => white ? 'il Bianco' : 'il Nero';
