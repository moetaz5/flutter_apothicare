import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 24);
    
    final firstControlPoint = Offset(size.width * 0.25, size.height);
    final firstEndPoint = Offset(size.width * 0.5, size.height - 14);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    final secondControlPoint = Offset(size.width * 0.75, size.height - 28);
    final secondEndPoint = Offset(size.width, size.height - 10);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = AppColors.forestGreen.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;

    final paint2 = Paint()
      ..color = AppColors.primaryGreen.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    // Wave 1
    final path1 = Path();
    path1.moveTo(0, size.height);
    path1.lineTo(0, size.height - 18);
    path1.quadraticBezierTo(size.width * 0.25, size.height - 34, size.width * 0.5, size.height - 18);
    path1.quadraticBezierTo(size.width * 0.75, size.height - 2, size.width, size.height - 18);
    path1.lineTo(size.width, size.height);
    path1.close();
    canvas.drawPath(path1, paint1);

    // Wave 2
    final path2 = Path();
    path2.moveTo(0, size.height);
    path2.lineTo(0, size.height - 24);
    path2.quadraticBezierTo(size.width * 0.25, size.height - 10, size.width * 0.5, size.height - 24);
    path2.quadraticBezierTo(size.width * 0.75, size.height - 38, size.width, size.height - 24);
    path2.lineTo(size.width, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
