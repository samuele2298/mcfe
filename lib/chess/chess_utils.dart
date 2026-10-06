import 'package:chess/chess.dart' as ch;

/// Posizione immutabile (sopra il motore mutabile del pacchetto `chess`, port di chess.js).
/// Tutte le mosse sono in UCI standard (arrocco e1g1, promozione e7e8q).
class Pos {
  Pos(this.fen) : _game = ch.Chess.fromFEN(fen, check_validity: false);

  static final initial = Pos('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');

  final String fen;
  final ch.Chess _game;
  List<LegalMove>? _moves;

  bool get whiteToMove => _game.turn == ch.Color.WHITE;
  bool get isCheck => _game.in_check;
  bool get isCheckmate => _game.in_checkmate;
  bool get isStalemate => _game.in_stalemate;
  bool get isDraw => _game.in_draw;
  bool get isGameOver => _game.game_over;

  int get fullmoves => int.tryParse(fen.split(' ').elementAtOrNull(5) ?? '') ?? 1;

  List<LegalMove> get legalMoves => _moves ??= [
        for (final m in _game.moves({'verbose': true}).cast<Map<String, dynamic>>())
          LegalMove(m['from'] as String, m['to'] as String, _promo(m), m['san'] as String),
      ];

  static String? _promo(Map<String, dynamic> m) {
    if (!(m['flags'] as String).contains('p')) return null;
    return RegExp(r'=([QRBN])').firstMatch(m['san'] as String)?.group(1)?.toLowerCase();
  }

  /// Destinazioni legali per casa di partenza.
  Map<String, Set<String>> get destinations {
    final out = <String, Set<String>>{};
    for (final m in legalMoves) {
      out.putIfAbsent(m.from, () => {}).add(m.to);
    }
    return out;
  }

  bool isPromotion(String from, String to) =>
      legalMoves.any((m) => m.from == from && m.to == to && m.promotion != null);

  bool isLegal(String uci) => play(uci) != null;

  /// Nuova posizione dopo la mossa, o null se illegale.
  Pos? play(String uci) {
    if (uci.length < 4) return null;
    final copy = _game.copy();
    final ok = copy.move({
      'from': uci.substring(0, 2),
      'to': uci.substring(2, 4),
      if (uci.length > 4) 'promotion': uci.substring(4, 5),
    });
    return ok ? Pos(copy.fen) : null;
  }

  /// SAN della mossa, o null se illegale.
  String? san(String uci) {
    final from = uci.substring(0, 2), to = uci.substring(2, 4);
    final promo = uci.length > 4 ? uci[4] : null;
    for (final m in _game.moves({'verbose': true}).cast<Map<String, dynamic>>()) {
      if (m['from'] == from && m['to'] == to) {
        final san = m['san'] as String;
        if (promo == null || san.toLowerCase().contains('=${promo.toLowerCase()}')) return san;
      }
    }
    return null;
  }

  /// UCI di una mossa in SAN, o null.
  String? uciFromSan(String san) {
    final clean = san.replaceAll(RegExp(r'[+#?!]+$'), '');
    for (final m in _game.moves({'verbose': true}).cast<Map<String, dynamic>>()) {
      if ((m['san'] as String).replaceAll(RegExp(r'[+#]+$'), '') == clean) {
        final promo = (m['flags'] as String).contains('p')
            ? RegExp(r'=([QRBN])').firstMatch(m['san'] as String)?.group(1)?.toLowerCase()
            : null;
        return '${m['from']}${m['to']}${promo ?? ''}';
      }
    }
    return null;
  }

  /// Pezzo sulla casa come 'wN', 'bK', ... oppure null.
  String? pieceAt(String square) {
    final p = _game.get(square);
    if (p == null) return null;
    return '${p.color == ch.Color.WHITE ? 'w' : 'b'}${p.type.name.toUpperCase()}';
  }

  /// Casa del re al tratto se è sotto scacco.
  String? get checkedKing {
    if (!isCheck) return null;
    final k = whiteToMove ? 'wK' : 'bK';
    for (final sq in allSquares) {
      if (pieceAt(sq) == k) return sq;
    }
    return null;
  }
}

class LegalMove {
  LegalMove(this.from, this.to, this.promotion, this.san);
  final String from;
  final String to;
  final String? promotion;
  final String san;
  String get uci => '$from$to${promotion ?? ''}';
}

const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
final allSquares = [for (var r = 1; r <= 8; r++) for (final f in files) '$f$r'];

/// Converte una sequenza UCI in SAN numerata a partire da una posizione.
String uciLineToSan(String fen, List<String> ucis, {int maxMoves = 12}) {
  var pos = Pos(fen);
  final parts = <String>[];
  for (final (i, u) in ucis.take(maxMoves).indexed) {
    final san = pos.san(u);
    final next = pos.play(u);
    if (san == null || next == null) break;
    if (pos.whiteToMove) {
      parts.add('${pos.fullmoves}. $san');
    } else {
      parts.add(i == 0 ? '${pos.fullmoves}... $san' : san);
    }
    pos = next;
  }
  return parts.join(' ');
}

/// Applica una lista di mosse UCI e restituisce tutte le posizioni (inclusa l'iniziale).
List<Pos> replay(String fen, List<String> ucis) {
  final out = [Pos(fen)];
  for (final u in ucis) {
    final next = out.last.play(u);
    if (next == null) break;
    out.add(next);
  }
  return out;
}
