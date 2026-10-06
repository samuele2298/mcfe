// Modelli JSON dell'API mcbe.

class User {
  User({required this.id, required this.email, required this.role, this.displayName, required this.ratingPuzzle});

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as String,
        email: j['email'] as String,
        role: j['role'] as String,
        displayName: j['displayName'] as String?,
        ratingPuzzle: j['ratingPuzzle'] as int,
      );

  final String id;
  final String email;
  final String role;
  final String? displayName;
  final int ratingPuzzle;

  bool get isAdmin => role == 'admin';
  String get name => displayName?.isNotEmpty == true ? displayName! : email.split('@').first;
}

class Puzzle {
  Puzzle({
    required this.id,
    required this.fen,
    required this.moves,
    required this.rating,
    required this.themes,
    required this.openingTags,
    required this.source,
  });

  factory Puzzle.fromJson(Map<String, dynamic> j) => Puzzle(
        id: j['id'] as String,
        fen: j['fen'] as String,
        moves: (j['moves'] as List).cast<String>(),
        rating: j['rating'] as int,
        themes: (j['themes'] as List).cast<String>(),
        openingTags: (j['openingTags'] as List? ?? const []).cast<String>(),
        source: j['source'] as String? ?? 'lichess',
      );

  final String id;
  final String fen;
  final List<String> moves;
  final int rating;
  final List<String> themes;
  final List<String> openingTags;
  final String source;
}

class ThemeInfo {
  ThemeInfo(this.key, this.label, this.group);
  factory ThemeInfo.fromJson(Map<String, dynamic> j) =>
      ThemeInfo(j['key'] as String, j['label'] as String, j['group'] as String);
  final String key;
  final String label;
  final String group;
}

class Weakness {
  Weakness({
    required this.dimension,
    required this.key,
    required this.label,
    required this.rating,
    required this.rd,
    required this.attempts,
    required this.successRate,
    required this.confident,
  });

  factory Weakness.fromJson(Map<String, dynamic> j) => Weakness(
        dimension: j['dimension'] as String,
        key: j['key'] as String,
        label: j['label'] as String,
        rating: j['rating'] as int,
        rd: j['rd'] as int,
        attempts: j['attempts'] as int,
        successRate: (j['successRate'] as num).toDouble(),
        confident: j['confident'] as bool,
      );

  final String dimension;
  final String key;
  final String label;
  final int rating;
  final int rd;
  final int attempts;
  final double successRate;
  final bool confident;
}

class StatChange {
  StatChange(this.dimension, this.key, this.before, this.after);
  factory StatChange.fromJson(Map<String, dynamic> j) =>
      StatChange(j['dimension'] as String, j['key'] as String, j['before'] as int, j['after'] as int);
  final String dimension;
  final String key;
  final int before;
  final int after;
}

class GameState {
  GameState({
    required this.id,
    required this.startFen,
    required this.fen,
    required this.moves,
    required this.sans,
    required this.userWhite,
    required this.mode,
    required this.opponentElo,
    required this.result,
    required this.termination,
    required this.whiteToMove,
    required this.analysisStatus,
    required this.adaptiveTarget,
    required this.awaitingDecision,
  });

  factory GameState.fromJson(Map<String, dynamic> j) => GameState(
        id: j['id'] as String,
        startFen: j['startFen'] as String,
        fen: j['fen'] as String,
        moves: (j['moves'] as List).cast<String>(),
        sans: (j['sans'] as List).cast<String>(),
        userWhite: j['userColor'] == 'white',
        mode: j['mode'] as String,
        opponentElo: j['opponentElo'] as int?,
        result: j['result'] as String?,
        termination: j['termination'] as String?,
        whiteToMove: j['turn'] == 'white',
        analysisStatus: j['analysisStatus'] as String,
        adaptiveTarget: j['adaptiveTarget'] as String?,
        awaitingDecision: j['awaitingDecision'] as bool? ?? false,
      );

  final String id;
  final String startFen;
  final String fen;
  final List<String> moves;
  final List<String> sans;
  final bool userWhite;
  final String mode;
  final int? opponentElo;
  final String? result;
  final String? termination;
  final bool whiteToMove;
  final String analysisStatus;
  final String? adaptiveTarget;
  final bool awaitingDecision;

  bool get finished => result != null;
  bool get userToMove => !finished && whiteToMove == userWhite && !awaitingDecision;

  /// Esito dal punto di vista dell'utente: 1 vittoria, 0.5 patta, 0 sconfitta.
  double? get userScore => switch (result) {
        '1-0' => userWhite ? 1 : 0,
        '0-1' => userWhite ? 0 : 1,
        '1/2-1/2' => 0.5,
        _ => null,
      };
}

class Diagnosis {
  Diagnosis(this.category, this.motif, this.phase, this.reasons);
  factory Diagnosis.fromJson(Map<String, dynamic> j) => Diagnosis(
        j['category'] as String,
        j['motif'] as String?,
        j['phase'] as String,
        (j['reasons'] as List).cast<String>(),
      );
  final String category;
  final String? motif;
  final String phase;
  final List<String> reasons;
}

class MoveFeedback {
  MoveFeedback({
    required this.uci,
    required this.san,
    required this.classification,
    required this.winPctLoss,
    required this.evalBefore,
    required this.evalAfter,
    this.bestUci,
    this.bestSan,
    this.diagnosis,
  });

  factory MoveFeedback.fromJson(Map<String, dynamic> j) => MoveFeedback(
        uci: j['uci'] as String,
        san: j['san'] as String,
        classification: j['classification'] as String,
        winPctLoss: (j['winPctLoss'] as num).toDouble(),
        evalBefore: j['evalBefore'] as int,
        evalAfter: j['evalAfter'] as int,
        bestUci: j['bestUci'] as String?,
        bestSan: j['bestSan'] as String?,
        diagnosis: j['diagnosis'] == null ? null : Diagnosis.fromJson(j['diagnosis'] as Map<String, dynamic>),
      );

  final String uci;
  final String san;
  final String classification;
  final double winPctLoss;
  final int evalBefore;
  final int evalAfter;
  final String? bestUci;
  final String? bestSan;
  final Diagnosis? diagnosis;

  bool get isBad => classification == 'mistake' || classification == 'blunder';
}

const classificationLabels = {
  'best': 'Mossa migliore',
  'ok': 'Buona mossa',
  'inaccuracy': 'Imprecisione',
  'mistake': 'Errore',
  'blunder': 'Grave errore',
};

const mistakeLabels = {
  'missed_mate': 'Matto mancato',
  'missed_tactic': 'Tattica mancata',
  'hanging_piece': 'Pezzo lasciato in presa',
  'allowed_tactic': 'Tattica concessa',
  'endgame_technique': 'Tecnica di finale',
  'opening_deviation': 'Imprecisione in apertura',
  'positional': 'Errore posizionale',
};

String formatEval(int cpWhite) {
  if (cpWhite.abs() >= 9000) {
    final n = 10000 - cpWhite.abs();
    return '${cpWhite > 0 ? '' : '-'}M$n';
  }
  final v = cpWhite / 100;
  return '${v > 0 ? '+' : ''}${v.toStringAsFixed(1)}';
}
