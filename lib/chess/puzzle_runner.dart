import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/models.dart';
import 'chess_utils.dart';

enum PuzzleStatus { loading, opponentMoving, playing, solved, failed }

/// Logica di un puzzle Lichess: la prima mossa è dell'avversario, poi l'utente deve
/// trovare le sue mosse; le risposte avversarie sono automatiche.
/// Sull'ultima mossa è accettato anche un matto alternativo.
class PuzzleRunner extends ChangeNotifier {
  PuzzleRunner(this.puzzle, {this.opponentDelay = const Duration(milliseconds: 500)}) {
    _position = Pos(puzzle.fen);
    _timer = Timer(opponentDelay, _playOpponent);
  }

  final Puzzle puzzle;
  final Duration opponentDelay;

  late Pos _position;
  String? _lastMove;
  int _ply = 0;
  PuzzleStatus _status = PuzzleStatus.opponentMoving;
  String? _wrongMove;
  bool _hintUsed = false;
  bool _failedOnce = false;
  bool _disposed = false;
  Timer? _timer;
  final Stopwatch _clock = Stopwatch();

  Pos get position => _position;
  String? get lastMove => _lastMove;
  PuzzleStatus get status => _status;
  String? get wrongMove => _wrongMove;
  bool get hintUsed => _hintUsed;

  /// true se l'utente ha sbagliato almeno una volta (esito del tentativo).
  bool get failedOnce => _failedOnce;
  bool get finished => _status == PuzzleStatus.solved || _status == PuzzleStatus.failed;
  int get elapsedMs => _clock.elapsedMilliseconds;

  /// L'utente gioca il colore che NON muove nella FEN iniziale.
  bool get userWhite => !Pos(puzzle.fen).whiteToMove;

  String? get expectedUci => _ply < puzzle.moves.length ? puzzle.moves[_ply] : null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _playOpponent() {
    final uci = expectedUci;
    if (uci == null || _disposed) return;
    _position = _position.play(uci) ?? _position;
    _lastMove = uci;
    _ply++;
    if (_ply >= puzzle.moves.length) {
      _status = PuzzleStatus.solved;
    } else {
      _status = PuzzleStatus.playing;
      _clock.start();
    }
    _notify();
  }

  /// Ritorna true se la mossa è corretta.
  bool userMove(String uci) {
    if (_status != PuzzleStatus.playing) return false;
    final san = _position.san(uci);
    final after = _position.play(uci);
    if (san == null || after == null) return false;
    final expectedSan = _position.san(expectedUci!);
    final isLast = _ply == puzzle.moves.length - 1;
    final correct = san == expectedSan || (isLast && after.isCheckmate);

    if (!correct) {
      _failedOnce = true;
      _wrongMove = uci;
      _status = PuzzleStatus.failed;
      _clock.stop();
      _notify();
      return false;
    }

    _wrongMove = null;
    _position = after;
    _lastMove = uci;
    _ply++;
    if (_ply >= puzzle.moves.length || after.isCheckmate) {
      _status = PuzzleStatus.solved;
      _clock.stop();
    } else {
      _status = PuzzleStatus.opponentMoving;
      _timer = Timer(const Duration(milliseconds: 350), _playOpponent);
    }
    _notify();
    return true;
  }

  /// Dopo un errore permette di riprovare dalla stessa posizione (il tentativo resta fallito).
  void retry() {
    if (_status != PuzzleStatus.failed) return;
    _wrongMove = null;
    _status = PuzzleStatus.playing;
    _notify();
  }

  String? hint() {
    _hintUsed = true;
    _notify();
    return expectedUci;
  }

  /// Mostra la soluzione giocando le mosse restanti.
  Future<void> showSolution() async {
    _failedOnce = true;
    _wrongMove = null;
    _status = PuzzleStatus.opponentMoving;
    _notify();
    while (_ply < puzzle.moves.length && !_disposed) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final uci = puzzle.moves[_ply];
      _position = _position.play(uci) ?? _position;
      _lastMove = uci;
      _ply++;
      _notify();
    }
    _status = PuzzleStatus.failed;
    _clock.stop();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
