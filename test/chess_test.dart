import 'package:flutter_test/flutter_test.dart';
import 'package:mentorchess/api/models.dart';
import 'package:mentorchess/chess/chess_utils.dart';
import 'package:mentorchess/chess/puzzle_runner.dart';

void main() {
  group('Pos', () {
    test('mosse legali, SAN e arrocco in UCI standard', () {
      final p = Pos('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
      expect(p.san('e1g1'), 'O-O');
      expect(p.san('e1c1'), 'O-O-O');
      expect(p.play('e1g1')!.pieceAt('g1'), 'wK');
      expect(p.play('e1e3'), isNull);
    });

    test('promozione', () {
      final p = Pos('8/4P3/8/8/8/8/k7/4K3 w - - 0 1');
      expect(p.isPromotion('e7', 'e8'), isTrue);
      expect(p.play('e7e8n')!.pieceAt('e8'), 'wN');
      expect(p.san('e7e8q'), 'e8=Q');
      expect(p.uciFromSan('e8=R'), 'e7e8r');
    });

    test('matto e scacco', () {
      final p = Pos.initial.play('f2f3')!.play('e7e5')!.play('g2g4')!.play('d8h4')!;
      expect(p.isCheckmate, isTrue);
      expect(p.checkedKing, 'e1');
    });

    test('linea in SAN numerata', () {
      expect(uciLineToSan(Pos.initial.fen, ['e2e4', 'e7e5', 'g1f3']), '1. e4 e5 2. Nf3');
    });
  });

  group('PuzzleRunner', () {
    // dump Lichess: puzzle 00008
    final puzzle = Puzzle(
      id: '00008',
      fen: 'r6k/pp2r2p/4Rp1Q/3p4/8/1N1P2R1/PqP2bPP/7K b - - 0 24',
      moves: ['f2g3', 'e6e7', 'b2b1', 'b3c1', 'b1c1', 'h6c1'],
      rating: 1800,
      themes: const ['crushing'],
      openingTags: const [],
      source: 'lichess',
    );

    test('risolve con le mosse giuste', () async {
      final r = PuzzleRunner(puzzle, opponentDelay: Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(r.userWhite, isTrue);
      expect(r.status, PuzzleStatus.playing);
      expect(r.userMove('e6e7'), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(r.userMove('b3c1'), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(r.userMove('h6c1'), isTrue);
      expect(r.status, PuzzleStatus.solved);
      expect(r.failedOnce, isFalse);
      r.dispose();
    });

    test('una mossa sbagliata fa fallire il puzzle', () async {
      final r = PuzzleRunner(puzzle, opponentDelay: Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(r.userMove('h6h7'), isFalse);
      expect(r.status, PuzzleStatus.failed);
      r.retry();
      expect(r.status, PuzzleStatus.playing);
      r.dispose();
    });
  });
}
