import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/constants/app_colors.dart';
import '../../data/services/upi_service.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _detected = false;
  String? _errorMsg;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;

      final data = UpiService.parseUpiQr(raw);
      if (data != null) {
        _detected = true;
        Navigator.of(context).pop(data);
        return;
      }

      // Non-UPI QR detected
      if (!_detected) {
        setState(() => _errorMsg = _categoriseError(raw));
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _errorMsg = null);
        });
      }
    }
  }

  String _categoriseError(String raw) {
    if (raw.startsWith('http') || raw.startsWith('www')) {
      return 'This looks like a website QR, not a UPI QR.';
    }
    if (raw.startsWith('tel:') || raw.startsWith('smsto:')) {
      return 'This is a phone QR code, not a UPI QR.';
    }
    return 'Not a valid UPI QR code. Please scan a UPI payment QR.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // Dim overlay with transparent cutout
          _ScannerOverlay(),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Scan UPI QR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // Torch toggle
                  GestureDetector(
                    onTap: () => _controller.toggleTorch(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.flash_on_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Instruction text below the scan box
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 260),
                const Text(
                  'Align QR code within the frame',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          // Error banner
          if (_errorMsg != null)
            Positioned(
              bottom: 60,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.expense,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.expense.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMsg!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 200.ms)
                  .slideY(begin: 0.3, duration: 200.ms),
            ),
        ],
      ),
    );
  }
}

/// Paints a dimmed overlay with a transparent square cutout for the scan area.
class _ScannerOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  static const _boxSize = 240.0;
  static const _cornerRadius = 16.0;
  static const _cornerLen = 28.0;
  static const _cornerThickness = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 - 30;
    final rect = Rect.fromCenter(
        center: Offset(cx, cy), width: _boxSize, height: _boxSize);

    // Dim background
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.62);
    final bgPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(_cornerRadius)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(bgPath, dimPaint);

    // Corner brackets
    final cPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = _cornerThickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final l = rect.left, t = rect.top, r = rect.right, b = rect.bottom;
    const cr = _cornerRadius;
    const cl = _cornerLen;

    // Top-left
    canvas.drawPath(
        Path()
          ..moveTo(l + cl, t)
          ..lineTo(l + cr, t)
          ..arcToPoint(Offset(l, t + cr),
              radius: const Radius.circular(_cornerRadius))
          ..lineTo(l, t + cl),
        cPaint);
    // Top-right
    canvas.drawPath(
        Path()
          ..moveTo(r - cl, t)
          ..lineTo(r - cr, t)
          ..arcToPoint(Offset(r, t + cr),
              radius: const Radius.circular(_cornerRadius), clockwise: false)
          ..lineTo(r, t + cl),
        cPaint);
    // Bottom-left
    canvas.drawPath(
        Path()
          ..moveTo(l, b - cl)
          ..lineTo(l, b - cr)
          ..arcToPoint(Offset(l + cr, b),
              radius: const Radius.circular(_cornerRadius), clockwise: false)
          ..lineTo(l + cl, b),
        cPaint);
    // Bottom-right
    canvas.drawPath(
        Path()
          ..moveTo(r, b - cl)
          ..lineTo(r, b - cr)
          ..arcToPoint(Offset(r - cr, b),
              radius: const Radius.circular(_cornerRadius))
          ..lineTo(r - cl, b),
        cPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
