import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CustomMapMarkerHelper {
  static BitmapDescriptor? dayMarker;
  static BitmapDescriptor? nightMarker;
  static BitmapDescriptor? selectedMarker;
  static BitmapDescriptor? userLocationMarker;
  static ui.Image? _caduceusAssetImage;

  static Future<void> initMarkers() async {
    try {
      // Load the official caduceus asset icon in high resolution for crisp rendering
      if (_caduceusAssetImage == null) {
        try {
          final ByteData data = await rootBundle.load('assets/images/icone-40.png');
          final ui.Codec codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(),
            targetWidth: 256,
          );
          final ui.FrameInfo fi = await codec.getNextFrame();
          _caduceusAssetImage = fi.image;
        } catch (_) {
          // Fallback to pure vector caduceus drawing
        }
      }

      dayMarker = await _createMarkerIcon(
        mainColor: const Color(0xFF1B5E20),
        accentColor: const Color(0xFF43A047),
        iconColor: const Color(0xFF1B5E20),
        isNight: false,
        isSelected: false,
      );

      nightMarker = await _createMarkerIcon(
        mainColor: const Color(0xFF311B92),
        accentColor: const Color(0xFF7C3AED),
        iconColor: const Color(0xFF4C1D95),
        isNight: true,
        isSelected: false,
      );

      selectedMarker = await _createMarkerIcon(
        mainColor: const Color(0xFF004D40),
        accentColor: const Color(0xFF00897B),
        iconColor: const Color(0xFF004D40),
        isNight: false,
        isSelected: true,
      );

      userLocationMarker = await _createUserLocationIcon();
    } catch (_) {
      dayMarker ??= BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      nightMarker ??= BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
      selectedMarker ??= BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      userLocationMarker ??= BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }

  static Future<BitmapDescriptor> _createUserLocationIcon() async {
    const double size = 30.0;
    const double pixelRatio = 3.0;

    final int pixelSize = (size * pixelRatio).round();
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    canvas.scale(pixelRatio, pixelRatio);

    const double center = size / 2;

    // 1. Soft Blue Outer Halo
    final Paint haloPaint = Paint()..color = const Color(0x352563EB);
    canvas.drawCircle(const Offset(center, center), 14.0, haloPaint);

    // 2. Crisp White Ring
    final Paint whiteRingPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(center, center), 9.5, whiteRingPaint);

    // White Ring Drop Shadow
    final Paint shadowPaint = Paint()
      ..color = const Color(0x30000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(const Offset(center, center), 9.5, shadowPaint);

    // 3. Vibrant Blue Center Core
    final Paint blueCorePaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(center - 7, center - 7),
        const Offset(center + 7, center + 7),
        [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
      );
    canvas.drawCircle(const Offset(center, center), 7.0, blueCorePaint);

    // 4. White Center Specular Dot
    final Paint dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawCircle(const Offset(center - 1.5, center - 1.5), 1.8, dotPaint);

    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image image = await picture.toImage(pixelSize, pixelSize);
    final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: pixelRatio,
    );
  }

  static Future<BitmapDescriptor> _createMarkerIcon({
    required Color mainColor,
    required Color accentColor,
    required Color iconColor,
    required bool isNight,
    required bool isSelected,
  }) async {
    // Balanced, modern logical dimensions for Google Maps pins
    final double width = isSelected ? 42.0 : 36.0;
    final double height = isSelected ? 52.0 : 45.0;
    const double pixelRatio = 3.0; // High DPI supersampling for ultra-crisp display

    final int pixelWidth = (width * pixelRatio).round();
    final int pixelHeight = (height * pixelRatio).round();

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // Apply pixel scaling to ensure sharp vector lines on all screen densities
    canvas.scale(pixelRatio, pixelRatio);

    final double centerX = width / 2;
    final double radius = isSelected ? 16.0 : 13.5;
    final double centerY = radius + 3.0;
    final double tipY = height - 4.0;

    // 1. Soft Realistic Drop Shadow under the pin tip
    final Paint shadowPaint = Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    final Path shadowPath = Path()
      ..addOval(Rect.fromCenter(center: Offset(centerX, height - 3.0), width: isSelected ? 16 : 13, height: 5.5));
    canvas.drawPath(shadowPath, shadowPaint);

    // 2. Main Pin Teardrop Body with sleek modern curve
    final Path pinPath = Path();
    pinPath.moveTo(centerX, tipY);
    pinPath.quadraticBezierTo(
      centerX - radius * 0.95,
      centerY + radius * 0.70,
      centerX - radius,
      centerY,
    );
    pinPath.arcToPoint(
      Offset(centerX + radius, centerY),
      radius: Radius.circular(radius),
      clockwise: true,
    );
    pinPath.quadraticBezierTo(
      centerX + radius * 0.95,
      centerY + radius * 0.70,
      centerX,
      tipY,
    );
    pinPath.close();

    // Pin Gradient Fill
    final Paint pinPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(centerX - radius, centerY - radius),
        Offset(centerX + radius, tipY),
        [accentColor, mainColor],
      );
    canvas.drawPath(pinPath, pinPaint);

    // Pin Outer Crisp White Border
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.0 : 1.6;
    canvas.drawPath(pinPath, borderPaint);

    // 3. Inner White Circle Badge with clean definition
    final double innerRadius = radius * 0.72;
    final Paint innerCirclePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(centerX, centerY), innerRadius, innerCirclePaint);

    // Inner subtle border
    final Paint innerRingPaint = Paint()
      ..color = iconColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    canvas.drawCircle(Offset(centerX, centerY), innerRadius - 0.3, innerRingPaint);

    // 4. Draw Official Caducée / Pharmacy symbol
    if (_caduceusAssetImage != null) {
      final double targetIconSize = innerRadius * 1.52;
      final Rect destRect = Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: targetIconSize,
        height: targetIconSize,
      );
      final Rect srcRect = Rect.fromLTWH(
        0,
        0,
        _caduceusAssetImage!.width.toDouble(),
        _caduceusAssetImage!.height.toDouble(),
      );

      final Paint iconPaint = Paint()
        ..colorFilter = ColorFilter.mode(iconColor, BlendMode.srcIn)
        ..filterQuality = FilterQuality.high;

      canvas.drawImageRect(_caduceusAssetImage!, srcRect, destRect, iconPaint);
    } else {
      _drawVectorCaducee(canvas, Offset(centerX, centerY), innerRadius * 1.5, iconColor);
    }

    // 5. Convert to BitmapDescriptor with exact pixel scaling
    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image image = await picture.toImage(pixelWidth, pixelHeight);
    final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: pixelRatio,
    );
  }

  static void _drawVectorCaducee(Canvas canvas, Offset center, double size, Color color) {
    final scale = size / 32.0;
    canvas.save();
    canvas.translate(center.dx - 16 * scale, center.dy - 16 * scale);
    canvas.scale(scale, scale);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // 1. Pedestal Base
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(10, 26, 12, 2.5), const Radius.circular(1.2)),
      fillPaint,
    );

    // 2. Stem
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(14.8, 17, 2.4, 9), const Radius.circular(1.0)),
      fillPaint,
    );

    // 3. Chalice Bowl
    final Path bowlPath = Path()
      ..moveTo(8.5, 11)
      ..cubicTo(8.5, 18.5, 12.0, 20.0, 16.0, 20.0)
      ..cubicTo(20.0, 20.0, 23.5, 18.5, 23.5, 11)
      ..close();
    canvas.drawPath(bowlPath, fillPaint);

    // 4. Serpent winding around stem and rising above bowl
    final Path snakePath = Path()
      ..moveTo(11.5, 25.0)
      ..cubicTo(20.0, 23.5, 20.0, 19.5, 14.0, 18.0)
      ..cubicTo(10.0, 17.0, 11.0, 12.5, 17.5, 11.5)
      ..cubicTo(22.0, 11.0, 23.0, 7.0, 19.5, 4.5)
      ..cubicTo(16.5, 2.5, 12.5, 4.8, 14.0, 7.5)
      ..cubicTo(15.0, 8.5, 17.5, 9.5, 16.0, 10.5);
    canvas.drawPath(snakePath, strokePaint);

    // Snake Head
    canvas.drawCircle(const Offset(15.0, 7.8), 1.8, fillPaint);

    canvas.restore();
  }
}
