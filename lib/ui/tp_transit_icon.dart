import 'package:flutter/widgets.dart';

/// 單軌、地鐵、高鐵的專屬交通圖示（草稿，之後可請設計精修）。
enum TpTransitGlyph { monorail, metro, hsr }

/// 24px 網格、1.8 描邊、圓端點的線條圖示，與 web `Icon` 元件同一份座標。
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
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color ?? const Color(0xFF000000);
    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), p);
    RRect box(double x, double y, double w, double h) =>
        RRect.fromLTRBR(x, y, x + w, y + h, const Radius.circular(3));

    switch (glyph) {
      case TpTransitGlyph.monorail: // 軌道梁在上的車廂
        line(3, 4, 21, 4);
        canvas.drawRRect(box(5, 7, 14, 9), p);
        line(5, 12, 19, 12);
        line(9, 4, 9, 7);
        line(15, 4, 15, 7);
        line(9, 19, 15, 19);
      case TpTransitGlyph.metro: // 車廂在地平線之上
        canvas.drawRRect(box(5, 3, 14, 13), p);
        line(5, 10, 19, 10);
        line(3, 20, 21, 20);
        line(9, 16, 8, 20);
        line(15, 16, 16, 20);
      case TpTransitGlyph.hsr: // 流線車頭
        canvas.drawPath(
          Path()
            ..moveTo(2, 15)
            ..cubicTo(2, 12, 5, 9, 10, 9)
            ..lineTo(16, 9)
            ..cubicTo(20, 9, 22, 12, 22, 15)
            ..lineTo(22, 16)
            ..lineTo(2, 16)
            ..close(),
          p,
        );
        line(12, 9, 12, 16);
        line(17, 9, 17, 16);
        line(2, 19, 22, 19);
    }
  }

  @override
  bool shouldRepaint(_TransitPainter old) =>
      old.glyph != glyph || old.color != color;
}
