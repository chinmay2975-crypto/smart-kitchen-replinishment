import 'package:flutter/material.dart';

/// Renders the jar/container visual: a lid, a rounded body clipped so the
/// region above the current fill level shows [emptyColor] (theme background)
/// and the region at/below it shows a solid fill color, plus measurement
/// ticks and an optional dashed reorder-level marker.
///
/// Coordinate space is a fixed 96x140 box (ported 1:1 from the web app's SVG
/// `buildContainerSvg` in frontend/js/devices.js — do not "simplify" these
/// numbers, they're intentionally matched).
class ContainerPainter extends CustomPainter {
  static const double _viewW = 96;
  static const double _viewH = 140;
  static const double bodyTop = 22;
  static const double bodyHeight = 108;
  static const double bodyLeft = 11;
  static const double bodyWidth = 74;
  static const double bodyBottom = bodyTop + bodyHeight;

  static const Color _borderNormal = Color(0xFF94A3B8);
  static const Color _borderLow = Color(0xFFEF4444);
  static const Color _fillNormal = Color(0xFF64748B);
  static const Color _fillLow = Color(0xFFEF4444);
  static const Color _markerColor = Color(0xFFEF4444);

  final double fillPct; // 0..100, already clamped by the caller
  final double? markerPct; // 0..100 or null
  final bool isLow;
  final Color emptyColor;

  const ContainerPainter({
    required this.fillPct,
    required this.markerPct,
    required this.isLow,
    required this.emptyColor,
  });

  Color get _borderColor => isLow ? _borderLow : _borderNormal;
  Color get _fillColor => isLow ? _fillLow : _fillNormal;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / _viewW;
    final scaleY = size.height / _viewH;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    // Lid
    _drawRoundedRect(canvas, const Rect.fromLTWH(30, 0, 36, 8), 3,
        fill: const Color(0xFFE2E8F0), stroke: _borderNormal);
    _drawRoundedRect(canvas, const Rect.fromLTWH(17, 6, 62, 14), 4,
        fill: const Color(0xFFCBD5E1), stroke: _borderNormal);

    // Body: empty region first, fill region on top, clipped to the rounded body.
    final bodyRect = const Rect.fromLTWH(bodyLeft, bodyTop, bodyWidth, bodyHeight);
    final bodyRRect = RRect.fromRectAndRadius(bodyRect, const Radius.circular(6));

    canvas.save();
    canvas.clipRRect(bodyRRect);
    canvas.drawRect(bodyRect, Paint()..color = emptyColor);

    final clampedFill = fillPct.clamp(0, 100).toDouble();
    final fillHeight = bodyHeight * clampedFill / 100;
    final fillY = bodyBottom - fillHeight;
    canvas.drawRect(
      Rect.fromLTWH(bodyLeft, fillY, bodyWidth, fillHeight),
      Paint()..color = _fillColor,
    );
    canvas.restore();

    // Outline
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _borderColor,
    );

    // Ticks at 25/50/75%
    final tickPaint = Paint()
      ..color = _borderColor
      ..strokeWidth = 1.5;
    for (final p in [25, 50, 75]) {
      final y = bodyBottom - bodyHeight * p / 100;
      canvas.drawLine(Offset(10, y), Offset(15, y), tickPaint);
    }

    // Reorder marker (dashed)
    if (markerPct != null) {
      final clampedMarker = markerPct!.clamp(0, 100).toDouble();
      final y = bodyBottom - bodyHeight * clampedMarker / 100;
      _drawDashedLine(
        canvas,
        Offset(bodyLeft, y),
        Offset(bodyLeft + bodyWidth, y),
        Paint()
          ..color = _markerColor
          ..strokeWidth = 1.5,
        dashWidth: 4,
        gapWidth: 2,
      );
    }

    canvas.restore();
  }

  void _drawRoundedRect(Canvas canvas, Rect rect, double radius,
      {required Color fill, required Color stroke}) {
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(rrect, Paint()..color = fill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = stroke,
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    required double dashWidth,
    required double gapWidth,
  }) {
    final totalLength = (end - start).distance;
    final direction = (end - start) / totalLength;
    var drawn = 0.0;
    while (drawn < totalLength) {
      final segmentEnd = (drawn + dashWidth).clamp(0, totalLength).toDouble();
      canvas.drawLine(
        start + direction * drawn,
        start + direction * segmentEnd,
        paint,
      );
      drawn += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(covariant ContainerPainter oldDelegate) {
    return oldDelegate.fillPct != fillPct ||
        oldDelegate.markerPct != markerPct ||
        oldDelegate.isLow != isLow ||
        oldDelegate.emptyColor != emptyColor;
  }
}
