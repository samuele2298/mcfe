import 'dart:math';

import 'package:flutter/material.dart';

import '../chess/chess_utils.dart';

const _light = Color(0xFFF0D9B5);
const _dark = Color(0xFFB58863);
const _lastMove = Color(0x809BC700);
const _selected = Color(0x8014551E);
const _check = Color(0xB0E53935);

class BoardArrow {
  const BoardArrow(this.uci, this.color);
  final String uci;
  final Color color;
}

BoardArrow goodArrow(String uci) => BoardArrow(uci, const Color(0xB015781B));
BoardArrow badArrow(String uci) => BoardArrow(uci, const Color(0xB0882020));
BoardArrow infoArrow(String uci) => BoardArrow(uci, const Color(0xB0003088));

/// Scacchiera: tocco o trascinamento, mosse legali, ultima mossa, scacco, frecce, promozione.
class ChessBoardView extends StatefulWidget {
  const ChessBoardView({
    super.key,
    required this.position,
    this.whiteBottom = true,
    this.lastMove,
    this.interactive = true,
    this.playerWhite,
    this.onMove,
    this.arrows = const [],
    this.maxSize = 640,
  });

  final Pos position;
  final bool whiteBottom;
  final String? lastMove;
  final bool interactive;

  /// Lato che l'utente può muovere (null = quello al tratto).
  final bool? playerWhite;
  final void Function(String uci)? onMove;
  final List<BoardArrow> arrows;
  final double maxSize;

  @override
  State<ChessBoardView> createState() => _ChessBoardViewState();
}

class _ChessBoardViewState extends State<ChessBoardView> {
  String? _selectedSq;
  String? _dragFrom;
  Offset? _dragPos;

  bool get _canMove =>
      widget.interactive &&
      widget.onMove != null &&
      !widget.position.isGameOver &&
      (widget.playerWhite == null || widget.playerWhite == widget.position.whiteToMove);

  @override
  void didUpdateWidget(ChessBoardView old) {
    super.didUpdateWidget(old);
    if (old.position.fen != widget.position.fen) {
      _selectedSq = null;
      _dragFrom = null;
    }
  }

  String _squareAt(Offset p, double sq) {
    var f = (p.dx / sq).floor().clamp(0, 7);
    var r = (p.dy / sq).floor().clamp(0, 7);
    if (widget.whiteBottom) {
      r = 7 - r;
    } else {
      f = 7 - f;
    }
    return '${files[f]}${r + 1}';
  }

  Offset _squareOrigin(String square, double sq) {
    final f = files.indexOf(square[0]);
    final r = int.parse(square[1]) - 1;
    final x = widget.whiteBottom ? f : 7 - f;
    final y = widget.whiteBottom ? 7 - r : r;
    return Offset(x * sq, y * sq);
  }

  bool _isOwnPiece(String square) {
    final p = widget.position.pieceAt(square);
    return p != null && (p[0] == 'w') == widget.position.whiteToMove;
  }

  Future<void> _tryMove(String from, String to) async {
    final pos = widget.position;
    if (!(pos.destinations[from]?.contains(to) ?? false)) return;
    var uci = '$from$to';
    if (pos.isPromotion(from, to)) {
      final role = await _askPromotion(pos.whiteToMove);
      if (role == null) return;
      uci += role;
    }
    setState(() => _selectedSq = null);
    widget.onMove?.call(uci);
  }

  Future<String?> _askPromotion(bool white) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Promozione'),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final r in ['q', 'r', 'b', 'n'])
                InkWell(
                  onTap: () => Navigator.pop(ctx, r),
                  child: Image.asset(pieceAsset('${white ? 'w' : 'b'}${r.toUpperCase()}'), width: 64, height: 64),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _onTapUp(TapUpDetails d, double sq) {
    if (!_canMove) return;
    final square = _squareAt(d.localPosition, sq);
    if (_selectedSq != null && _selectedSq != square && !_isOwnPiece(square)) {
      _tryMove(_selectedSq!, square);
      return;
    }
    setState(() => _selectedSq = _isOwnPiece(square) && _selectedSq != square ? square : null);
  }

  void _onPanStart(DragStartDetails d, double sq) {
    if (!_canMove) return;
    final square = _squareAt(d.localPosition, sq);
    if (!_isOwnPiece(square)) return;
    setState(() {
      _dragFrom = square;
      _selectedSq = square;
      _dragPos = d.localPosition;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_dragFrom == null) return;
    setState(() => _dragPos = d.localPosition);
  }

  void _onPanEnd(double sq) {
    final from = _dragFrom;
    final pos = _dragPos;
    setState(() {
      _dragFrom = null;
      _dragPos = null;
    });
    if (from == null || pos == null) return;
    final to = _squareAt(pos, sq);
    if (to != from) _tryMove(from, to);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = min(widget.maxSize, min(c.maxWidth, c.maxHeight.isFinite ? c.maxHeight : c.maxWidth));
      final sq = size / 8;
      final pos = widget.position;
      final dests = _selectedSq != null && _canMove ? (pos.destinations[_selectedSq] ?? <String>{}) : <String>{};
      final last = widget.lastMove;

      return Center(
        child: SizedBox(
          width: size,
          height: size,
          child: GestureDetector(
            onTapUp: (d) => _onTapUp(d, sq),
            onPanStart: (d) => _onPanStart(d, sq),
            onPanUpdate: _onPanUpdate,
            onPanEnd: (_) => _onPanEnd(sq),
            child: Stack(children: [
              CustomPaint(
                size: Size(size, size),
                painter: _SquaresPainter(
                  origin: (s) => _squareOrigin(s, sq),
                  sq: sq,
                  highlights: {
                    if (last != null && last.length >= 4) last.substring(0, 2): _lastMove,
                    if (last != null && last.length >= 4) last.substring(2, 4): _lastMove,
                    if (_selectedSq != null) _selectedSq!: _selected,
                    if (pos.checkedKing != null) pos.checkedKing!: _check,
                  },
                  whiteBottom: widget.whiteBottom,
                ),
              ),
              for (final s in allSquares)
                if (pos.pieceAt(s) case final piece? when s != _dragFrom)
                  Positioned(
                    left: _squareOrigin(s, sq).dx,
                    top: _squareOrigin(s, sq).dy,
                    width: sq,
                    height: sq,
                    child: IgnorePointer(child: Image.asset(pieceAsset(piece), filterQuality: FilterQuality.medium)),
                  ),
              IgnorePointer(
                child: CustomPaint(
                  size: Size(size, size),
                  painter: _OverlayPainter(
                    origin: (s) => _squareOrigin(s, sq),
                    sq: sq,
                    dests: dests,
                    occupied: {for (final d in dests) if (pos.pieceAt(d) != null) d},
                    arrows: widget.arrows,
                  ),
                ),
              ),
              if (_dragFrom != null && _dragPos != null)
                Positioned(
                  left: _dragPos!.dx - sq * 0.75,
                  top: _dragPos!.dy - sq * 0.75,
                  width: sq * 1.5,
                  height: sq * 1.5,
                  child: IgnorePointer(child: Image.asset(pieceAsset(pos.pieceAt(_dragFrom!)!))),
                ),
            ]),
          ),
        ),
      );
    });
  }
}

String pieceAsset(String piece) => 'assets/pieces/cburnett/$piece.png';

class _SquaresPainter extends CustomPainter {
  _SquaresPainter({required this.origin, required this.sq, required this.highlights, required this.whiteBottom});
  final Offset Function(String) origin;
  final double sq;
  final Map<String, Color> highlights;
  final bool whiteBottom;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in allSquares) {
      final f = files.indexOf(s[0]);
      final r = int.parse(s[1]) - 1;
      final rect = origin(s) & Size(sq, sq);
      canvas.drawRect(rect, Paint()..color = (f + r).isEven ? _dark : _light);
      final h = highlights[s];
      if (h != null) canvas.drawRect(rect, Paint()..color = h);
    }
    // coordinate
    final style = TextStyle(fontSize: sq * 0.18, fontWeight: FontWeight.w600);
    for (var i = 0; i < 8; i++) {
      final file = whiteBottom ? files[i] : files[7 - i];
      final rank = whiteBottom ? 8 - i : i + 1;
      _text(canvas, file, Offset(i * sq + sq * 0.82, 8 * sq - sq * 0.24), style.copyWith(color: i.isEven ? _light : _dark));
      _text(canvas, '$rank', Offset(sq * 0.05, i * sq + sq * 0.03), style.copyWith(color: i.isEven ? _dark : _light));
    }
  }

  void _text(Canvas canvas, String t, Offset at, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: t, style: style), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_SquaresPainter old) =>
      old.sq != sq || old.whiteBottom != whiteBottom || old.highlights.toString() != highlights.toString();
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({required this.origin, required this.sq, required this.dests, required this.occupied, required this.arrows});
  final Offset Function(String) origin;
  final double sq;
  final Set<String> dests;
  final Set<String> occupied;
  final List<BoardArrow> arrows;

  Offset _center(String s) => origin(s) + Offset(sq / 2, sq / 2);

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = const Color(0x5014551E);
    for (final d in dests) {
      if (occupied.contains(d)) {
        canvas.drawCircle(_center(d), sq * 0.46, Paint()
          ..color = const Color(0x5014551E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sq * 0.08);
      } else {
        canvas.drawCircle(_center(d), sq * 0.15, dot);
      }
    }
    for (final a in arrows) {
      if (a.uci.length < 4) continue;
      final from = _center(a.uci.substring(0, 2));
      final to = _center(a.uci.substring(2, 4));
      final dir = (to - from);
      final len = dir.distance;
      if (len == 0) continue;
      final unit = dir / len;
      final head = sq * 0.38;
      final end = to - unit * head * 0.9;
      final paint = Paint()
        ..color = a.color
        ..strokeWidth = sq * 0.16
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(from + unit * sq * 0.2, end, paint);
      final normal = Offset(-unit.dy, unit.dx);
      final path = Path()
        ..moveTo(to.dx, to.dy)
        ..lineTo((end + normal * head * 0.7).dx, (end + normal * head * 0.7).dy)
        ..lineTo((end - normal * head * 0.7).dx, (end - normal * head * 0.7).dy)
        ..close();
      canvas.drawPath(path, Paint()..color = a.color);
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => true;
}
