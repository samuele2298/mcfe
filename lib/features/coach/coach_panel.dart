import 'package:flutter/material.dart';

/// Pulsante "Chiedi al coach" (implementazione completa nella Fase 5).
class CoachButton extends StatelessWidget {
  const CoachButton({super.key, required this.fen, this.context, this.moves});
  final String fen;
  final String? context;
  final List<String>? moves;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
