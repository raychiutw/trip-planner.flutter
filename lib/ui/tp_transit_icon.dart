import 'package:flutter/widgets.dart';

/// 單軌、地鐵、高鐵的專屬交通圖示（草稿，之後可請設計精修）。
enum TpTransitGlyph { monorail, metro, hsr }

/// 24px 網格的實心填色圖示（與 Material 實心的火車、公車同風格），
/// 座標與 web `Icon` 元件同一份（皆 evenodd 挖空）。
/// Cupertino／Material 沒有這三個符號，故自繪；顏色預設取 [IconTheme]。
class TpTransitIcon extends StatelessWidget {
  const TpTransitIcon({
    super.key,
    required this.glyph,
    this.size = 24,
    this.color,
  });

  final TpTransitGlyph glyph;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _TransitPainter(glyph, color ?? IconTheme.of(context).color),
      ),
    );
  }
}

class _TransitPainter extends CustomPainter {
  _TransitPainter(this.glyph, this.color);

  final TpTransitGlyph glyph;
  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final p = Paint()
      ..style = PaintingStyle.fill
      ..color = color ?? const Color(0xFF000000);
    final path = Path()..fillType = PathFillType.evenOdd;
    void rect(double x, double y, double w, double h) =>
        path.addRect(Rect.fromLTWH(x, y, w, h));
    void rrect(double x, double y, double w, double h, double r) =>
        path.addRRect(RRect.fromLTRBR(x, y, x + w, y + h, Radius.circular(r)));

    switch (glyph) {
      case TpTransitGlyph.monorail: // 車廂騎在軌道梁上
        rrect(5, 3, 14, 13, 3.5);
        rrect(7.5, 6, 9, 5, 1);
        rect(8, 16, 2, 2);
        rect(14, 16, 2, 2);
        rrect(2, 18, 20, 3, 1);
      case TpTransitGlyph.metro: // 車廂立在軌道上
        rrect(4, 3, 16, 13, 4);
        rrect(6.5, 6, 11, 5, 1.2);
        path.addOval(
          Rect.fromCircle(center: const Offset(8.5, 13.5), radius: 1.1),
        );
        path.addOval(
          Rect.fromCircle(center: const Offset(15.5, 13.5), radius: 1.1),
        );
        path.addPolygon(const [
          Offset(8, 16),
          Offset(10, 16),
          Offset(8.5, 21),
          Offset(6.5, 21),
        ], true);
        path.addPolygon(const [
          Offset(14, 16),
          Offset(16, 16),
          Offset(17.5, 21),
          Offset(15.5, 21),
        ], true);
        rect(2, 21, 20, 1.5);
      case TpTransitGlyph.hsr: // 流線車頭
        path
          ..moveTo(1.5, 16.5)
          ..cubicTo(1.5, 13, 6, 8, 11, 8)
          ..lineTo(19.5, 8)
          ..arcToPoint(const Offset(22.5, 11), radius: const Radius.circular(3))
          ..lineTo(22.5, 14.5)
          ..arcToPoint(
            const Offset(20.5, 16.5),
            radius: const Radius.circular(2),
          )
          ..close();
        path
          ..moveTo(6.2, 13)
          ..cubicTo(7.2, 11, 8.8, 10, 10.5, 10)
          ..lineTo(10.5, 13)
          ..close();
        rect(12.5, 10, 3, 3);
        rect(17, 10, 3, 3);
        rect(6, 16.5, 2, 3);
        rect(16, 16.5, 2, 3);
        rect(2, 19.5, 20, 1.5);
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_TransitPainter old) =>
      old.glyph != glyph || old.color != color;
}
