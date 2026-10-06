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
